package SkyNet::Server;

use strict;
use warnings;
use IO::Socket;
use IO::Multiplex;
use Term::ANSIColor;
use JSON;
use SkyNet::User;
use SkyNet::Dispatcher;

my $mux    = IO::Multiplex->new();
my $socket = undef;

sub new {
    my ( $class, $args ) = @_;

    my $self = bless {
        'port'     => $args->{port},
        'debug'    => $args->{debug},
        'dispatch' => undef,
        'json'     => JSON->new->allow_nonref,
    }, $class;

    $self->{dispatch} = SkyNet::Dispatcher->new(
        {
            'debug' => $args->{debug},

            #'server'=> $self,
        }
    );
    $self->{dispatch}->{'server'} = $self;

    return $self;
}

sub start {
    my $self = shift;

    $socket = IO::Socket::INET->new(
        Listen    => 5,
        LocalAddr => '0.0.0.0',
        LocalPort => $self->{'port'},
        Proto     => 'tcp',
        ReusePort => 1,
        Blocking  => 0,
    ) || die "cannot create socket $!";

    $self->log_this("Awaiting connections on port $self->{port}");

    # We use the listen method instead of the add method.
    $mux->listen($socket);
    $mux->set_callback_object($self);    #__PACKAGE__);
    $mux->loop;
}

# mux_connection is called when a new connection is accepted.
sub mux_connection {
    my $self = shift;
    my $mux  = shift;
    my $fh   = shift;

    # Construct a new User object
    SkyNet::User->new(
        {
            'mux'    => $mux,
            'fh'     => $fh,
            'server' => $self,
        }
    );
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
