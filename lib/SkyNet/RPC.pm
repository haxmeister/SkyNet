package SkyNet::RPC;

use strict;
use warnings;
use JSON;
use Data::Dumper;

sub playerseen {
    my $caller = shift;
    my $data   = shift;
    my $sender = shift;

    foreach my $player ( @{ $data->{playerlist} } ) {
        $player->{shipname} = $player->{shipname} || "station";
        print STDERR "Seen: [$player->{guildtag}] $player->{name} in $player->{shipname} at $player->{sectorid}\n";
        my $sql ="INSERT INTO seen (guildtag, name, sectorid, shipname, reporter) VALUES (?,?,?,?,?)";
        my $sth = $sender->{db}->prepare($sql);
            $sth->execute(
                $player->{guildtag},
                $player->{name},
                $player->{sectorid},
                $player->{shipname},
                $player->{reporter},
            );
            $sth->finish();
            $sender->{db}->commit or print STDERR $DBI::errstr;
    }

    # send data to all permissioned users
    $data->{result} = 1;
    foreach my $user ( SkyNet::User::users() ) {
        if ($user->{allowed}{seespots}){
            my $msg = encode_json($data);
            my $fh = $sender->{fh};
            print $fh "$msg\r\n" unless $user eq $sender;
        }
    }
}

sub channel {
    my $caller = shift;
    my $data   = shift;
    my $sender = shift;
    $data->{result} = 1;

    foreach my $user ( SkyNet::User::users() ) {
        if ($user->{allowed}{seechat}){
            my $msg = encode_json($data);
            my $fh  = $sender->{fh};
            print $fh "$msg\r\n" unless $user eq $sender;
        }
    }
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

    if (@result_list){
        print STDERR $data->{username}." has logged in\n";

        # respond to user client that the auth was successful
        my $msg = '{"action":"auth","result":1}';
        my $fh  = $sender->{fh};
        print $fh "$msg\r\n";

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

sub adduser{
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
                1, #seespots
                1, #see chat
                0, #manage users
                1, # manage warranties
                0, # manage statuses
                1, # see statuses
                1, # see warranties
                0 # add bots
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


1;
