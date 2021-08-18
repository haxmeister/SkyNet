package SkyNet::User;

use strict;
use warnings;
use JSON;
my %users = ();

sub new {
    my $package = shift;
    my %args    = @_;

    my $self = bless {
        'mux'     => $args{mux},
        'fh'      => $args{fh},
        'rpc'     => $args{rpc},
        'db'      => $args{db},
        'name'    => '',
        'allowed' => {
            'seespots' => 0,    # can see spots
            'seechat'  => 0,    # can see alliance chat
            'manuser'  => 0,    # can add/remove users
            'manwarr'  => 0,    # can add/remove warranty time
            'manstat'  => 0,    # can change kos, ally, status
            'seestat'  => 0,    # can see kos, ally, status
            'seewarr'  => 0,    # can see active warranties
            'addbot'   => 0,    # can add a bot user
        },
    }, $package;

    # Register the new User object as the callback specifically for
    # this file handle.
    $self->{mux}->set_callback_object( $self, $self->{fh} );
    print STDERR "New user connected..\n";

    # Register this User object in the main list of Users
    $users{$self} = $self;
}

sub users { return values %users; }

sub mux_input {
    my $self = shift;
    shift;    # mux not needed
    shift;    # fh not needed
    my $input = shift; # Scalar reference to the input

    while ( $$input =~ s/^(.*?)\r\n// ) {
        $self->process_command($1);
    }
}

sub mux_close {
    my $self = shift;

    # User disconnected;
    # [Notify other Users or something...]
    print STDERR  "User ".$self->{name}." disconnected..\n";
    delete $users{$self};
}

sub process_command {
    my $self = shift;
    my $cmd  = shift;
    my $data;
    my $action;

    print STDERR $cmd."received \n";
    $data = decode_json($cmd);
    print STDERR "eval ok\n";
    return unless defined( $data->{action} );
    print STDERR "action defined ok\n";
    $action = $data->{action};
    if ( $self->{rpc}->can($action) ) {
        $self->{rpc}->$action( $data, $self );
    }
    else{
        print STDERR "\n\n" . encode_json($data) . "\n\n";
    }
}

# recieves a hashref that is a chat message action and
# sends it to the user if they have permissions to see it
sub send_chat_message {
    my $self    = shift;
    my $msgData = shift;
    my $fh      = $self->{fh};

    if ( $self->{'allowed'}{'seechat'} ) {
        my $msgStr = encode_json($msgData);
        print $fh "$msgStr\r\n";
    }
}

sub send_playerseen {
    my $self    = shift;
    my $msgData = shift;
    my $fh      = $self->{fh};

    if ( $self->{'allowed'}{'seespots'} ) {
        my $msgStr = encode_json($msgData);
        print $fh "$msgStr\r\n";
    }
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

