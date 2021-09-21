package SkyNet::RPC;

use strict;
use warnings;
use JSON;
use Data::Dumper;

sub playerseen {
    my $caller = shift;
    my $data   = shift;
    my $sender = shift;
    $data->{result} = 1;
    $sender->spot_broadcast($data);
}

sub channel {
    my $caller = shift;
    my $data   = shift;
    my $sender = shift;
    $data->{result} = 1;
    $sender->chat_broadcast($data);
}

sub auth {
    my $caller = shift;
    my $data   = shift;
    my $sender = shift;

    $sender->{server}->DBconnect();
    my @result_list;
    my $sql = "SELECT * from users where username = ? and password = ?";
    my $sth = $sender->{db}->prepare($sql);
    $sth->execute($data->{username}, $data->{password});

    while(my $row = $sth->fetchrow_hashref()){
        push(@result_list, $row);
    }
    $sth->finish();

    # when the login successful
    if (@result_list){
        
        $sender->{loggedIn} = 1;
        print STDERR $data->{username}." has logged in\n";
        
        # respond to user client that the auth was successful
        my $msg = '{"action":"auth","result":1}';
        my $fh  = $sender->{fh};
        print $fh "$msg\r\n";

        # update user name
        $sender->{name} = $data->{username};

        # notify others of login
        $sender->skynet_msg_all($data->{username}." arrived..");

        # respond to user who is online
        my $users_online = join ' : ',$sender->get_online_user_names();
        $sender->skynet_msg("Users online: ($users_online)");

        # Set permissions to match the database results (from first match)
        foreach my $key (keys %{$result_list[0]}){
            if (exists $sender->{allowed}{$key}){
                $sender->{allowed}{$key} = $result_list[0]{$key};
            }
        }
    }else{

        print STDERR "failed login attempt ".encode_json($data)."\n";
        my $msg = '{"action":"auth","result":0,"error":"user not found"}';
        my $fh  = $sender->{fh};
        print $fh ( $msg . "\r\n" );
    }
}

# voce incompatible adduser
sub sn_adduser{
    # {"username":"Munny","password":"bananafire35","action":"adduser"}
    my $caller = shift;
    my $data   = shift;
    my $sender = shift;
    my $sql;
    my $msg;

    if ($sender->{allowed}{manuser}){
        $sender->{server}->DBconnect();
        $sql = "delete from users where username='".$data->{username}."'";
        my $sth = $sender->{db}->prepare($sql);
        $sth->execute();
        $sth->finish();

        $sql = "INSERT INTO users (username, password, seespots, seechat, manuser, manwarr, manstat, seestat, seewarr, addbot) VALUES(?,?,?,?,?,?,?,?,?,?)";
        $sth = $sender->{db}->prepare($sql);
        $sth->execute(
                $data->{username},
                $data->{password},
                $data->{seespots},# seespots
                $data->{seechat}, # see chat
                $data->{manuser}, # manage users
                $data->{manwarr}, # manage warranties
                $data->{manstat}, # manage statuses
                $data->{seestat}, # see statuses
                $data->{seewarr}, # see warranties
                $data->{addbot},  # add bots
            );
        $sth->finish();
        $sender->{db}->commit or print STDERR $DBI::errstr;
        $sender->skynet_msg($data->{name}." has been added to Skynet");
    }else{
        my $msg = '{"action":"adduser","result":0,"msg":"Not authorized to manage users"}';
        print {$sender->{fh}} $msg;
    }
}

sub removeuser{
    my $caller = shift;
    my $data   = shift;
    my $sender = shift;
    my $sql;
    my $msg;

    if ($sender->{allowed}{manuser}){
        $sender->{server}->DBconnect();
        $sql = "delete from users where username='".$data->{username}."'";
        my $sth = $sender->{db}->prepare($sql);
        $sth->execute();
        $sth->finish();
        $sender->{db}->commit or print STDERR $DBI::errstr;
    }else{
        my $msg = '{"action":"removeuser","result":0,"msg":"Not authorized to manage users"}';
        print {$sender->{fh}} $msg;
    }   
}

sub logout {
    my $caller = shift;
    my $data   = shift;
    my $sender = shift;
    print STDERR "logout: " . encode_json($data)."\n";
}

sub playerstatus {
    my $caller = shift;
    my $data   = shift;
    my $sender = shift;
    my %res = (
        "action"     => "playerstatus",
        "name"       => $data->{name},
        "result"     => 1,        
    );

    # check user permissions
    if (! $sender->{allowed}{seestat}){
        return;
    }
    $sender->{server}->log_this("Status check..");
    $sender->{server}->DBconnect();
    my $sth = $sender->{db}->prepare("SELECT * FROM playerlist WHERE name = ?");
    $sth->execute($data->{name});
    my $row = $sth->fetchrow_hashref();
    $sth->finish();

    my $statustype;
    my $status;
    my $elapsed;
    my $now = time();
    my $remaining;
    if ($row) {
            if ($row->{'type'} ==1 ) { # KOS
                $statustype = 1;
                $status = 'Player is KOS';
            } elsif ($row->{'type'} == 2) {
                $statustype = 3;
                $status = 'Player is ALLY';
            } else {
                $elapsed = $now - $row->{'ts'}; # Seconds elapsed
                $remaining = $row->{'length'} - $elapsed;
                if ($remaining<60) { # Expired
                    $statustype = 1;
                    $status = 'Payment expired!';
                    $sth = $sender->{db}->prepare("DELETE FROM playerlist WHERE id=?");
                    $sth->execute($row->{'id'});
                } else {
                    $status = 'Paid - remaining: ' . getTimeStr($remaining);
                    $statustype = 2;
                }
            }
        } else {
            $statustype = 3;
            $status = 'Nothing found.';
        }
        $res{'status'} = $status;
        $res{'statustype'} = $statustype;
        $sender->respond(\%res);
}

sub announce {
    my $caller = shift;
    my $data   = shift;
    my $sender = shift;

    $data->{result} = 1;
    $sender->announce_broadcast($data);
}

sub list{
    my $caller = shift;
    my $data   = shift;
    my $sender = shift;
    my $now    = time();
    my %res = (
        'action' => 'showlist',
        'result' => 1,
        'list'   => [],
    );
    $sender->{server}->DBconnect();
    my $sth = $sender->{db}->prepare("SELECT * FROM playerlist ORDER BY type, name");
    $sth->execute();
    
    my $count = 0;
    while(my $row = $sth->fetchrow_hashref()){
        my $remaining = '--';
        
        if($row->{type} eq 0){
            if (! $sender->{allowed}{seewarr}){next;}
            $row->{type} = "PAID";
            $remaining = getTimeStr($row->{length} - ($now - $row->{ts}));
        }
        elsif($row->{type} eq 1){
            if (! $sender->{allowed}{seestat}){next;}
            $row->{type} = "KOS";
            $remaining = getTimeStr($row->{length} - ($now - $row->{ts}));
        }
        elsif($row->{type} eq 2){
            if (! $sender->{allowed}{seestat}){next;}
            $row->{type} = "ALLY";
        }
        
        
        push(@{$res{list}}, {
            'status'   => $row->{type},
            'name'     => $row->{name},
            'addedby'  => $row->{addedby},
            'remaining'=> $remaining,
            'notes'    => $row->{notes},
    });
    }
    $sth->finish();

    if ($res{list}){
        $sender->respond(\%res);
        $sender->{server}->log_this("list is not empty");
    }
    else{
        $sender->respond({
            'action' => 'list',
            'result' => 0,
            'error'  => "list is empty..",
        });
        $sender->{server}->log_this("list is empty");
    }
}

sub listpayment{
    my $caller = shift;
    my $data   = shift;
    my $sender = shift;
    my $now    = time();
    my %res = (
        'action' => 'showlist',
        'result' => 1,
        'list'   => [],
    );

    # check user permissions
    if (! $sender->{allowed}{seestat}){
        $sender->respond({action=>'showlist', result=>'0',msg => "Not authorized to see status list.."});
        return;
    }

    # prepare query
    $sender->{server}->DBconnect();
    my $sth = $sender->{db}->prepare("SELECT * FROM playerlist WHERE type=0 ORDER BY name");
    $sth->execute();
    
    my $count = 0;
    while(my $row = $sth->fetchrow_hashref()){
        my $remaining = '--';
                   
        $row->{type} = "PAID";
        $remaining = getTimeStr($row->{length} - ($now - $row->{ts}));
        
        
        push(@{$res{list}}, {
            'status'   => $row->{type},
            'name'     => $row->{name},
            'addedby'  => $row->{addedby},
            'remaining'=> $remaining,
            'notes'    => $row->{notes},
        });
    }
    $sth->finish();

    if ($res{list}){
        $sender->respond(\%res);
        print STDERR "list is not empty\n";
    }
    else{
        $sender->respond({
            'action' => 'list',
            'result' => 0,
            'error'  => "list is empty..",
        });
        print STDERR "list is empty\n";
    }   
}

sub listkos{
    my $caller = shift;
    my $data   = shift;
    my $sender = shift;
    my $now    = time();
    my %res = (
        'action' => 'showlist',
        'result' => 1,
        'list'   => [],
    );

    # check user permissions
    if (! $sender->{allowed}{seestat}){
        $sender->respond({action=>'showlist', result=>'0',msg => "Not authorized to see status list.."});
        return;
    }

    # prepare query
    $sender->{server}->DBconnect();
    my $sth = $sender->{db}->prepare("SELECT * FROM playerlist WHERE type=1 ORDER BY name");
    $sth->execute();
    
    my $count = 0;
    while(my $row = $sth->fetchrow_hashref()){
        my $remaining = '--';
                   
        $row->{type} = "KOS";
        $remaining = getTimeStr($row->{length} - ($now - $row->{ts}));
        
        
        push(@{$res{list}}, {
            'status'   => $row->{type},
            'name'     => $row->{name},
            'addedby'  => $row->{addedby},
            'remaining'=> $remaining,
            'notes'    => $row->{notes},
        });
    }
    $sth->finish();

    if ($res{list}){
        $sender->respond(\%res);
        $sender->{server}->log_this("list is not empty");
    }
    else{
        $sender->respond({
            'action' => 'list',
            'result' => 0,
            'error'  => "list is empty..",
        });
        $sender->{server}->log_this("list is empty");
    }   
}

sub listallies{
    my $caller = shift;
    my $data   = shift;
    my $sender = shift;
    my $now    = time();
    my %res = (
        'action' => 'showlist',
        'result' => 1,
        'list'   => [],
    );

    # check user permissions
    if (! $sender->{allowed}{seestat}){
        $sender->respond({action=>'showlist', result=>'0',msg => "Not authorized to see status list.."});
        return;
    }

    # prepare query
    $sender->{server}->DBconnect();
    my $sth = $sender->{db}->prepare("SELECT * FROM playerlist WHERE type=2 ORDER BY name");
    $sth->execute();
    
    my $count = 0;
    while(my $row = $sth->fetchrow_hashref()){
        my $remaining = '--';
                   
        $row->{type} = "ALLY";
        $remaining = getTimeStr($row->{length} - ($now - $row->{ts}));
        
        push(@{$res{list}}, {
            'status'   => $row->{type},
            'name'     => $row->{name},
            'addedby'  => $row->{addedby},
            'remaining'=> $remaining,
            'notes'    => $row->{notes},
        });
    }
    $sth->finish();

    if ($res{list}){
        $sender->respond(\%res);
        $sender->{server}->log_this("list is not empty");
    }
    else{
        $sender->respond({
            'action' => 'list',
            'result' => 0,
            'error'  => "list is empty..",
        });
        $sender->{server}->log_this("list is empty");
    }   
}

sub addpayment{
    my $caller = shift;
    my $data   = shift;
    my $sender = shift;
    my $now    = time(); 
    my %res = (
        'action'=>"addpayment", 
        'name'  =>$data->{name}
    );

    #check permissions
    if (! $sender->{allowed}{manwarr}){
        $sender->respond({action=>'addpayment', result=>'0',error => "Not authorized to manage warranties.."});
        return;
    }
    my @match = $data->{length} =~ /^(\d+)([dhm]?)$/;

    if(! @match){
        $res{'result'} = 0;
        $res{'error'}  = "Invalid time period parameter.";
    }else{
        my $length = $match[0];
        my $interval = $match[1];

        if ($interval eq 'd'){
            $length  *= 86400;
        }elsif($interval eq 'h'){
            $length *= 3600;
        }else{
            $length *= 60;
        }

        # remove previous entry (per yt)
        $sender->{server}->DBconnect();
        my $sql = "DELETE FROM playerlist WHERE name=?";
        my $sth = $sender->{db}->prepare($sql);
        $sth->execute($data->{name});
        $sth->finish();

        $sql = "INSERT INTO playerlist (type, ts, name, length, addedby) VALUES(?,?,?,?,?)";
        $sth = $sender->{db}->prepare($sql);
        $sth->execute(
            0, 
            $now, 
            $data->{name}, 
            $length, 
            $data->{addedby},
        );
        $sth->finish();
        $res{result} = 1;
    }
    $sender->respond(\%res);

    foreach my $user ( SkyNet::User::users() ) {
        if ($user->{allowed}{seewarr}){
            $user->skynet_msg($data->{name}." purchased a warranty from ".$sender->{name}."!");
        }
    }
}

sub removepayment{
    my $caller = shift;
    my $data   = shift;
    my $sender = shift;
 
    #check permissions
    if (! $sender->{allowed}{manwarr}){
        $sender->respond({action=>'removepayment', result=>'0',error => "Not authorized to manage warranties.."});
        return;
    }
    $sender->{server}->DBconnect();
    my $sql = "DELETE FROM playerlist WHERE name=?";
    my $sth = $sender->{db}->prepare($sql);
    $sth->execute($data->{name});
    $sth->finish();
    $sender->respond({action=>'removepayment', result=>'1'});

        foreach my $user ( SkyNet::User::users() ) {
        if ($user->{allowed}{seewarr}){
            $user->skynet_msg($data->{name}."'s warranty has been removed by ".$sender->{name}."!");
        }
    }
}

sub addkos{
    my $caller = shift;
    my $data   = shift;
    my $sender = shift;
    my $now    = time(); 
    my %res = (
        'action'=>"addkos", 
        'name'  =>$data->{name}
    );

    #check permissions
    if (! $sender->{allowed}{manstat}){
        $sender->respond({action=>'addkos', result=>'0',error => "Not authorized to manage statuses.."});
        return;
    }

    my @match = $data->{length} =~ /^(\d+)([dhm]?)$/;
    if(! @match){
        $res{'result'} = 0;
        $res{'error'}  = "Invalid time period parameter.";
    }else{
        my $length = $match[0];
        my $interval = $match[1];

        if ($interval eq 'd'){
            $length  *= 86400;
        }elsif($interval eq 'h'){
            $length *= 3600;
        }else{
            $length *= 60;
        }

        
        $sender->{server}->DBconnect();
        my $sql = "DELETE FROM playerlist WHERE name=?";
        my $sth = $sender->{db}->prepare($sql);
        $sth->execute($data->{name});
        $sth->finish();
        $sender->{db}->commit or print STDERR $DBI::errstr;

        $sql = "INSERT INTO playerlist (type, ts, name, length, addedby, notes) VALUES(?,?,?,?,?,?)";
        $sth = $sender->{db}->prepare($sql);
        $sth->execute(
            1, 
            $now, 
            $data->{name}, 
            $length, 
            $sender->{name},
            $data->{notes},
        );
        $sth->finish();
        $res{result} = 1;
    }
    $sender->respond(\%res);

    foreach my $user ( SkyNet::User::users() ) {
        if ($user->{allowed}{seestat}){
            $user->skynet_msg($data->{name}." has been labeled KOS by ".$sender->{name}."!");
        }
    }
}

sub removekos{
    my $caller = shift;
    my $data   = shift;
    my $sender = shift;
 
    #check permissions
    if (! $sender->{allowed}{manstat}){
        $sender->respond({action=>'removekos', result=>'0',error => "Not authorized to manage statuses.."});
        return;
    }
    $sender->{server}->DBconnect();
    my $sql = "DELETE FROM playerlist WHERE name=?";
    my $sth = $sender->{db}->prepare($sql);
    $sth->execute($data->{name});
    $sth->finish();
    $sender->respond({action=>'removekos', result=>'1'});

    foreach my $user ( SkyNet::User::users() ) {
        if ($user->{allowed}{seestat}){
            $user->skynet_msg($data->{name}."'s KOS has been removed by ".$sender->{name}."!");
        }
    }
}

sub addally{
     my $caller = shift;
    my $data   = shift;
    my $sender = shift;
    my $now    = time(); 
    my %res = (
        'action'=>"addally", 
        'name'  =>$data->{name}
    );

    #check permissions
    if (! $sender->{allowed}{manstat}){
        $sender->respond({action=>'addlps', result=>'0',error => "Not authorized to manage statuses.."});
        return;
    }

    $sender->{server}->DBconnect();
    my $sql = "DELETE FROM playerlist WHERE name=?";
    my $sth = $sender->{db}->prepare($sql);
    $sth->execute($data->{name});
    $sth->finish();
    $sender->{db}->commit or print STDERR $DBI::errstr;

    $sql = "INSERT INTO playerlist (type, ts, name, addedby) VALUES(?,?,?,?)";
    $sth = $sender->{db}->prepare($sql);
    $sth->execute(
        2, 
        $now, 
        $data->{name}, 
        $sender->{name},
    );
    $sth->finish();
    $sender->{db}->commit or print STDERR $DBI::errstr;

    $res{result} = 1;
    $sender->respond(\%res);

    foreach my $user ( SkyNet::User::users() ) {
        if ($user->{allowed}{seestat}){
            $user->skynet_msg($data->{name}." has been labeled ALLY by ".$sender->{name}."!");
        }
    } 

}

sub removeally{
    my $caller = shift;
    my $data   = shift;
    my $sender = shift;
 
    #check permissions
    if (! $sender->{allowed}{manstat}){
        $sender->respond({action=>'removeally', result=>'0',error => "Not authorized to manage statuses.."});
        return;
    }
    $sender->{server}->DBconnect();
    my $sql = "DELETE FROM playerlist WHERE name=?";
    my $sth = $sender->{db}->prepare($sql);
    $sth->execute($data->{name});
    $sth->finish();
    
    $sender->respond({action=>'removeally', result=>'1'});

    foreach my $user ( SkyNet::User::users() ) {
        if ($user->{allowed}{seestat}){
            $user->skynet_msg($data->{name}."'s ALLY status has been removed by ".$sender->{name}."!");
        }
    }

}

sub getTimeStr {
    my $secs = shift;
    if ($secs<0) {
            return "--";
    }
    my $days = int($secs / 86400);
    my $rem = $secs - ($days*86400);
    my $hours = int($rem / 3600);
    $rem = $rem - ($hours * 3600);
    my $min = int($rem / 60);
    return sprintf("%dd %02dh %02dm", $days, $hours, $min);
}
1;
