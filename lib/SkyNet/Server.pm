package SkyNet::Server;

use strict;
use warnings;
use IO::Socket;
use IO::Multiplex;
use SkyNet::User;
use SkyNet::RPC;

sub new {
    my $class = shift;
    my %args  = @_;
    my $self  = {
        'mux' => IO::Multiplex->new(),
        'db'  => SkyNet::DB->new(
                   'username' => $args{db_username},
                   'password' => $args{db_password},
                 ),
    };
    $self->{'db'}->db_connect();
    bless $self, $class;
    return $self;
}

sub listen_on_port{
    my $self = shift;
    my $port = shift;
    my $socket = IO::Socket::INET->new(
        Listen    => 5,
        LocalAddr => '0.0.0.0',
        LocalPort => $port,
        Proto     => 'tcp',
        ReusePort => 1,
        Blocking  => 0,
    ) || die "cannot create socket $!";
    print "Listening on port $port..\n";
    # setup multiplexer to watch server socket for events
    $self->{mux}->listen($socket);

    # set this package as a place to look for mux callbacks
    $self->{mux}->set_callback_object($self);
}

sub loop{
    my $self = shift;
    #start select loop
    $self->{mux}->loop;
}

# mux_connection is called when a new connection is accepted.
sub mux_connection {
    my $self = shift;
    my $mux  = shift;
    my $fh   = shift;

    # Construct a new User object
    SkyNet::User->new(
            'mux'    => $mux,
            'fh'     => $fh,
            'db'     => $self->{db},
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
