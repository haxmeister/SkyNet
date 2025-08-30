use v5.42;
use experimental qw(class);
no warnings 'experimental::class';

class SkyNet::User v1.0.0;

use Util::H2O;
use SkyNet::Protocol::Actions;

field $server   :reader :param ;
field $name     :reader :param;
field $socket   :param;
field $stream   :reader;
field $action   :reader;;
field $loggedIn :reader;
field $allowed  :reader;


ADJUST{
    $stream = SkyNet::Protocol::Stream->new( handle => $socket,);
    $stream->set_user($self);
    $action = SkyNet::Protocol::Actions->new(user => $self);
    $server->loop->add($stream);

    $allowed = h2o {
        'seespots' => 0,    # can see spots
        'seechat'  => 0,    # can see alliance chat
        'manuser'  => 0,    # can add/remove users
        'manwarr'  => 0,    # can add/remove warranty time
        'manstat'  => 0,    # can change kos, ally, status
        'seestat'  => 0,    # can see kos, ally, status
        'seewarr'  => 0,    # can see active warranties
        'addbot'   => 0,    # can add a bot user
        'announce' => 0,    # can see announcements
    };
}

method on_msg($msg_hash){
    try{
        my $method = $msg_hash->{action};
        my $res = $self->action->$method($msg_hash);
        if( $res ){
            $self->send( $res );
        }

    }
    catch ($e){
        say $e;
    }
}

method dismiss(){
    $stream->close_now;
    $server->del_user($self);
}

method send($msg_ref){
    $stream->write($msg_ref);
}

