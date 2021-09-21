package SkyNet::User;

use strict;
use warnings;
use JSON;
use SkyNet::RPC;
my %users = ();

sub new {
    my $package = shift;
    my %args    = @_;

    my $self = bless {
        'mux'     => $args{mux},
        'fh'      => $args{fh},
        'db'      => $args{db},
        'server'  => $args{server},
        'name'    => 'unlogged-user',
        'loggedIn'=> 0,
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
    $self->{server}->log_this("New user connected..");

    # Register this User object in the main list of Users
    $users{$self} = $self;
}

sub users { return values %users; }

# message received
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
    $self->{server}->log_this("User ".$self->{name}." disconnected..");
    delete $users{$self};
    # notify others of logoff
    $self->skynet_msg_all($self->{name}." departed..");
    
    
}

sub process_command {
    my $self = shift;
    my $cmd  = shift;

    #print STDERR $cmd."received \n";

    # attempt to successfully decode the json
    my $data;
    if ( eval{$data = decode_json($cmd);1;} ){

        # if there's no action in the message then drop it and move on
        return unless defined( $data->{action} );

        # look for rpc by the same name as action field
        my $action = $data->{action};
        if ( SkyNet::RPC->can($action) ) {
            $self->{server}->log_this("$action ..received from: ".$self->{name});
            SkyNet::RPC::->$action( $data, $self );
        }
        else{
            # actions with no rpc get the json dumped to stderr
            $self->{server}->log_this("\n\n" . encode_json($data) . "\n\n");
        }
    }
}

sub respond{
    my $self = shift;
    my $msg_data = shift;
    
    print {$self->{fh}} encode_json($msg_data)."\r\n";
}

sub skynet_msg{
    my $self = shift;
    my $text = shift;
    my $data  = {
        'action' => 'skynetmessage',
        'msg'    => $text,
        'result' => 1,
    };
    my $fh = $self->{fh};
    my $msg = encode_json($data);

    if ($self->{loggedIn}){
        $self->{server}->log_this( "sending $msg to ".$self->{name});
        print $fh "$msg\r\n";
    }

}

sub skynet_msg_all{
    my $self = shift;
    my $text = shift;
    foreach my $user ( SkyNet::User::users() ) {
        $user->skynet_msg($text);
    }
}

sub get_online_user_names{
    my $self = shift;
    my @userlist;
    foreach my $user ( SkyNet::User::users() ) {
        push @userlist, $user->{name};
    }
    return @userlist;
}

sub chat_broadcast{
    my $self = shift;
    my $data = shift;
    my $msg  = encode_json($data);

    foreach my $user ( SkyNet::User::users() ) {
        if ($user->{allowed}{seechat}){
            print {$user->{fh}} "$msg\r\n";# unless $user->{fh} eq $self->{fh};
        }
    }
}

sub spot_broadcast{
    my $self = shift;
    my $data = shift;
    foreach my $user ( SkyNet::User::users() ) {
        if ($user->{allowed}{seespots}){
            my $msg = encode_json($data);
            print {$user->{fh}} "$msg\r\n" unless $user eq $self;
        }
    }
}

sub announce_broadcast{
    my $self = shift;
    my $data = shift;

    foreach my $user ( SkyNet::User::users() ) {
        my $msg = encode_json($data);
        print {$user->{fh}} "$msg\r\n" unless $user eq $self;
    }
}

1;

