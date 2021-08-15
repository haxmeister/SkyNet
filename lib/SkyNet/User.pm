package SkyNet::User;

use strict;
use warnings;
use Data::Dumper;
my %users = ();

sub new {
    my $package = shift;
    my $args    = shift;

    my $self = bless {
        'mux'     => $args->{mux},
        'fh'      => $args->{fh},
        'server'  => $args->{server},
        'name'    => '',
        'allowed' => {
            'seespots' => 1,    # can see spots
            'seechat'  => 1,    # can see alliance chat
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
    $self->{server}->log_this("New user connected..");

    #print $self->{fh}
    #   "Greetings, Professor.  Would you like to play a game?\n";

    # Register this User object in the main list of Users
    $users{$self} = $self;

    #$self->{mux}->set_timeout( $self->{fh}, 1 );
}

sub users { return values %users; }

sub mux_input {
    my $self = shift;
    shift;
    shift;    # These two args are boring
    my $input = shift;    # Scalar reference to the input

    while ( $$input =~ s/^(.*?)\r\n// ) {
        $self->process_command($1);
    }
}

sub mux_close {
    my $self = shift;

    # User disconnected;
    # [Notify other Users or something...]
    $self->{server}->log_this("New user connected..");
    delete $users{$self};
}

# This gets called every second to update User info, etc...
#sub mux_timeout {
#my $self = shift;
#my $mux  = shift;

#$self->heartbeat;
#$self->mux->set_timeout( $self->{fh}, 1 );
#}

sub process_command {
    my $self = shift;
    my $cmd  = shift;
    my $data;
    my $action;

    eval { $data = $self->{server}->{json}->decode($cmd); 1; } or return;
    next unless defined( $data->{action} );

    $action = $data->{action};
    if ( $self->{server}->{dispatch}->can($action) ) {
        $self->{server}->{dispatch}->$action( $data, $self );
    }
    else {
        print STDERR "\n\n" . $self->{server}->{json}->encode($data) . "\n\n";
    }
}

# recieves a hashref that is a chat message action and
# sends it to the user if they have permissions to see it
sub send_chat_message {
    my $self    = shift;
    my $msgData = shift;

    if ( $self->{'allowed'}{'seechat'} ) {
        my $msgStr = encode_json($msgData);
        $self->{mux}->write( $self->{fh}, "$msgStr\r\n" );
    }
}

sub send_playerseen {
    my $self    = shift;
    my $msgData = shift;

    if ( $self->{'allowed'}{'seespots'} ) {
        my $msgStr = $self->{server}->{json}->encode($msgData);
        $self->{mux}->write( $self->{fh}, "$msgStr\r\n" );
    }
}

1;

