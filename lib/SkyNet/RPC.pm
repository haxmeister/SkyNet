package SkyNet::RPC;

use strict;
use warnings;
use JSON;
use Data::Dumper;

my $server;
my $db;

sub new {
    my $class = shift;
    my %args = @_;
    my $self  = bless {
        'db' => $args{'db'},
    }, $class;
    return $self;
}

sub playerseen {
    my $self   = shift;
    my $data   = shift;
    my $sender = shift;

    foreach my $player ( @{ $data->{playerlist} } ) {
        print STDERR "Seen: [$player->{guildtag}] $player->{name} in $player->{shipname}\n";
    }

    # send data to all permissioned users
    $data->{result} = 1;
    foreach my $user ( SkyNet::User::users() ) {
        $user->send_playerseen($data);    #unless $user eq $this_user;
    }
}

sub channel {
    my $self   = shift;
    my $data   = shift;
    my $sender = shift;
    $data->{result} = 1;

    foreach my $user ( SkyNet::User::users() ) {
        $user->send_chat_message($data) unless $user eq $sender;
    }
}

sub auth {
    my $self   = shift;
    my $data   = shift;
    my $user   = shift;
    print Dumper $data;
    print $data->{password}."\n";
    my $results = $self->{db}->authenticate_user(
                    $data->{username},
                    $data->{password}
                  );

    if ($results){
        print STDERR $data->{username}." has logged in\n";
        my $msg = '{"action":"auth","result":1}';
        my $fh  = $user->{fh};
        print $fh ( $msg . "\r\n" );
        foreach my $key (keys %{$results->[0]}){
            if (exists $user->{allowed}{$key}){
                $user->{allowed}{$key} = $results->[0]{$key};
            }
        }
    }else{
        print STDERR "failed login..\n";
        my $msg = '{"action":"auth","result":0,}';
        my $fh  = $user->{fh};
        print $fh ( $msg . "\r\n" );
    }
    print Dumper $user->{allowed};
    #
}

sub logout {
    my $self      = shift;
    my $data      = shift;
    my $this_user = shift;
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
1;
