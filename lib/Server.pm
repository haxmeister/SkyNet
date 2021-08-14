package SkyNet::Server;

use strict;
use warnings;
use IO::Socket;
use IO::Multiplex;
use SkyNet::Pilot;

my $mux    = IO::Multiplex->new();
my $socket = IO::Socket::INET->new(
        Listen    => 5,
        LocalAddr => '0.0.0.0',
        LocalPort => $self->{'server_port'},
        Proto     => 'tcp',
        ReusePort => 1,
        Blocking  => 0,
    ) || die "cannot create socket $!";


sub new {
    my ( $class, $args ) = @_;

    my $self = bless {
        'port'  => $args->{'port'},
        'debug' => $args->{'debug'},
    }, $class;

    return $self;
}

sub start{
    my $self = shift;

    # We use the listen method instead of the add method.
    $mux->listen($sock);

    $mux->set_callback_object(__PACKAGE__);
    $mux->loop;
}

# mux_connection is called when a new connection is accepted.
sub mux_connection {
    my $self = shift;
    my $mux  = shift;
    my $fh   = shift;

    # Construct a new Pilot object
    SkyNet::Pilot->new($mux, $fh);
}

1;
