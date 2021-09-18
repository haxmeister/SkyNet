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
        my $msg = '{"action":"auth","result":0,}';
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
        # check if user is already present
        $sql = "select * from users where username='".$data->{username}."'";
        my $sth = $sender->{db}->prepare($sql);
        $sth->execute();
        if (my $row = $sth->fetchrow_hashref()){
            $msg = '{"action":"adduser","result":0,"error":"User already exists"}';
            print STDERR "user already exists\n sending: $msg\n";
            print {$sender->{fh}} $msg."\r\n";
            $sth->finish();
            return;
        }

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
    }else{
        my $msg = '{"action":"adduser","result":0,"msg":"Not authorized to manage users"}';
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

    
    print STDERR "Status check..\n";
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
                    $status = 'Paid - remaining: ' . $caller->getTimeStr($remaining);
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

sub getlist{
    my $caller = shift;
    my $data   = shift;
    my $sender = shift;
    my $now    = time();   
}

sub list{
    my $caller = shift;
    my $data   = shift;
    my $sender = shift;
    my $now    = time();
    my %res = (
        'action' => 'getlist',
        'result' => 1,
        'list'   => [],
    );
    my $sth = $sender->{db}->prepare("SELECT * FROM playerlist ORDER BY type, name");
    $sth->execute();
    while(my $row = $sth->fetchrow_hashref()){
        push(@{$res{list}}, $row);
    }
    $sth->finish();
    $sender->respond(\%res);
    $sender->{fh};
}

sub listpayment{}
sub listkos{}
sub listallies{}

sub getTimeStr {
    my $caller = shift;
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
