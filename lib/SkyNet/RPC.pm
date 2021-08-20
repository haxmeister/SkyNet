package SkyNet::RPC;

use strict;
use warnings;
use JSON;
use Data::Dumper;

sub playerseen {
    my $data   = shift;
    my $sender = shift;

    foreach my $player ( @{ $data->{playerlist} } ) {
        print STDERR "Seen: [$player->{guildtag}] $player->{name} in $player->{shipname}\n";
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
    my $data   = shift;
    my $sender = shift;

    my $results = $sender->{db}->authenticate_user(
                    $data->{username},
                    $data->{password}
                  );

    if ($results){
        print STDERR $data->{username}." has logged in\n";

        # respond to user client that the auth was successful
        my $msg = '{"action":"auth","result":1}';
        my $fh  = $sender->{fh};
        print $fh "$msg\r\n";

        # Set permissions to match the database results (from first match)
        foreach my $key (keys %{$results->[0]}){
            if (exists $sender->{allowed}{$key}){
                $sender->{allowed}{$key} = $results->[0]{$key};
            }
        }
    }else{

        print STDERR "failed login attempt ".encode_json($data)."\n";
        my $msg = '{"action":"auth","result":0,}';
        my $fh  = $sender->{fh};
        print $fh ( $msg . "\r\n" );
    }
    print Dumper $sender->{allowed};
    #
}

sub logout {
    my $data   = shift;
    my $sender = shift;
    print STDERR "logout: " . encode_json($data)."\n";
}

## accepts a string and outputs it to STDERR with nice colored format
## and a time stamp
sub log_this {
    my $self = shift;
    my $line = shift;
    print color('grey10');
    print STDERR $self->timestamp();
    print color('white');
    print " $line \n";
    print color('reset');
}

sub timestamp {
    my $self   = shift;
    my @months = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
    my @days   = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime();
    my $month = $mon + 1;
    $year = $year + 1900;
    return "[$month/$mday/$year $hour:$min:$sec]";
}

1;
