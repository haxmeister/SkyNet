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

    # set a timer callback for 10 seconds 
    $self->{mux}->set_timeout($self->{fh}, 10);
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
    delete $users{$self} if exists $users{$self};
    # notify others of disconnect
    $self->skynet_msg_all($self->{name}." disconnected..");
    
}


sub mux_timeout {
    my $self = shift;
    my $mux  = shift;
    
    # unlogged users get dumped after 10 seconds
    if (! $self->{loggedIn}){
        delete $users{$self} if exists $users{$self};
        $self->{mux}->remove($self->{fh});
        $self->{mux}->close($self->{fh});
    }
    #$self->heartbeat;
    #$mux->set_timeout($self->{fh}, 1);
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
            $self->{server}->log_this("\n command not found \n" . encode_json($data) . "\n\n");
        }
    }
}

sub respond{
    my $self = shift;
    my $msg_data = shift;
    
    print {$self->{fh}} encode_json($msg_data)."\r\n";
}

# accepts a string and sends as
# server message to this user if logged in
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
        $self->{server}->log_this( "sending Skynet msg: $msg to ".$self->{name});
        print $fh "$msg\r\n";
    }

}

# accepts a string and sends as
# server message to all logged in users
sub skynet_msg_all{
    my $self = shift;
    my $text = shift;
    foreach my $user ( SkyNet::User::users() ) {
        $user->skynet_msg($text);
    }
}

sub get_online_user_names{
    my $self = shift;
    my %userlist;
    my @results;

    foreach my $user ( SkyNet::User::users() ) {
        if($user->is_logged_in){
           if(exists $userlist{$user->{name}}){
               print STDERR $user->{name}."exists\n";
               $userlist{$user->{name}} = $userlist{$user->{name}} + 1;
               print STDERR $user->{name}."is logged in ".$userlist{$user->{name}." times.")}
           }else{
               $userlist{$user->{name}} = 1;
           }
        }
    }
    print STDERR encode_json(%userlist);

    foreach my $name (keys %userlist){
        push (@results, "$name(".$userlist{$name}.")")
    }

    return keys @results;
}

# accepts a chat message object and sends
# to all users who can see chat and are logged in
sub chat_broadcast{
    my $self = shift;
    my $data = shift;
    my $msg  = encode_json($data);

    foreach my $user ( SkyNet::User::users() ) {
        if ($user->can_see_chat and $user->is_logged_in){
            print {$user->{fh}} "$msg\r\n" unless $user eq $self;
        }
    }
}

sub spot_broadcast{
    my $self = shift;
    my $data = shift;
    foreach my $user ( SkyNet::User::users() ) {
        if ($user->can_see_spots and $self->is_logged_in){
            my $msg = encode_json($data);
            print {$user->{fh}} "$msg\r\n" unless $user eq $self;
        }
    }
}

# accepts an announce message object and sends
# to all users who are logged in
sub announce_broadcast{
    my $self = shift;
    my $data = shift;
    my $msg = encode_json($data);

    foreach my $user ( SkyNet::User::users() ) {
        if ($user->is_logged_in){
            print {$user->{fh}} "$msg\r\n" unless $user eq $self;
        }
    }
}

sub remove_user_by_name{
    my $self = shift;
    my $name = shift;
    foreach my $user ( SkyNet::User::users() ) {
        if ($user->{name} eq $name){
            $user->logout();
        }
    }
}

sub logout{
    my $self = shift;
    $self->{loggedIn} = 0;
    delete $users{$self} if exists $users{$self};
    $self->{mux}->remove($self->{fh});
    $self->{mux}->close($self->{fh});
    $self->skynet_msg_all($self->{name}." logged out.");
}

sub is_logged_in{
    my $self = shift;
    return $self->{loggedIn};
}

sub can_see_chat{
    my $self = shift;
    return $self->{allowed}{seechat};
}

sub can_see_spots{
    my $self = shift;
    return $self->{allowed}{seespots};
}

sub can_manage_users{
    my $self = shift;
    return $self->{allowed}{manuser};
}

sub can_manage_warranties{
    my $self = shift;
    return $self->{allowed}{manwarr};
}

sub can_see_warranties{
    my $self = shift;
    return $self->{allowed}{seewarr};
}

sub can_manage_statuses{
    my $self = shift;
    return $self->{allowed}{manstat};
}

sub can_see_statuses{
    my $self = shift;
    return $self->{allowed}{seestat};
}

sub can_add_bots{
    my $self = shift;
    return $self->{allowed}{addbot};
}

1;

