use v5.42;
use experimental qw(class);
no warnings 'experimental::class';

class SkyNet::Server v1.0.0;

use IO::Async::Loop;
use IO::Async::Listener;
use SkyNet::User;
use SkyNet::Protocol::Stream;
use SkyNet::DB;
use DBI;

field $port         :param;
field $color_output :param //= '';
field $loop         :reader;
field $db           :reader;
field %users        :reader;

ADJUST{
    $loop = IO::Async::Loop->new();
    $db   = SkyNet::DB->new(dbname => 'skynet');
}

method start{
    $loop->listen(
        service  => $port,
        socktype => 'stream',

        on_accept => sub{
            my ($socket) = @_;
            my $address = $socket->peerhost . ":" . $socket->peerport;

            my $new_user = SkyNet::User->new(
                server => $self,
                socket => $socket,
                name   => $address,
            );

            say "new user connected at $address";
            $self->add_user($new_user);
        },
    )->get();

    say "Listening on port ".$port;
    $loop->run;
}

method add_user($user){
    $users{$user} = $user;
    say "New user joined";
    say scalar( keys %users )." users connected";
}

method del_user($user){
    say $user->name." disconnected";
    delete $users{$user};
    say scalar(keys %users)." users connected";
}

method broadcast($msg_ref, $permission){
    foreach my $user (keys %users){
        if($users{$user}->allowed->$permission){
            $users{$user}->send($msg_ref);
        }
    }
}

method broadcast_skynet_msg($msg){
    my $res = {
        'action' => 'skynetmessage',
        'msg'    => $msg,
        'result' => 1,
    };
    foreach my $user (keys %users){
        if($users{$user}->allowed->seestat){
            $users{$user}->send($res);
        }
    }
}

