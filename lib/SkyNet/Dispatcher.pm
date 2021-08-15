package SkyNet::Dispatcher;

use strict;
use warnings;
use SkyNet::DB;

sub new {
    my ( $class, $args ) = @_;
    my $self = bless {
        'debug'  => $args->{debug},
        'server' => $args->{server},
    }, $class;
    return $self;
}

sub playerseen {
    my $self      = shift;
    my $data      = shift;
    my $this_user = shift;
    foreach my $player ( @{ $data->{playerlist} } ) {
        $self->{server}->log_this("Seen: [$player->{guildtag}] $player->{name} in $player->{shipname}");
    }
    $data->{result} = 1;
    foreach my $user ( SkyNet::User::users() ) {
        $user->send_playerseen($data);    #unless $user eq $this_user;
    }
}

sub chat {
    my $self      = shift;
    my $data      = shift;
    my $this_user = shift;
    $data->{result} = 1;

    foreach my $user ( SkyNet::User::users() ) {
        $user->send_chat_message($data);    #unless $user eq $this_user;
    }
}

sub auth {
    my $self      = shift;
    my $data      = shift;
    my $this_user = shift;

    # fake confirmation for now
    $self->{server}->log_this("$data->{username} has logged in");
    my $msg = '{"action":"auth","result":1}';
    my $fh  = $this_user->{fh};
    print $fh ( $msg . "\r\n" );
}

sub logout {
    my $self      = shift;
    my $data      = shift;
    my $this_user = shift;
    print STDERR "logout: " . $self->{server}->{json}->encode($data) . "\n";
}

1;
