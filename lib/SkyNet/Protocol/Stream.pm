package SkyNet::Protocol::Stream;

use v5.42;
use parent qw( IO::Async::Stream );
use JSON;

my $json = JSON->new()->pretty(1);

sub new ($class, %params){
    my $self = $class->SUPER::new(handle => $params{handle});
    $self->{cb_object} = '';
    return $self;
}

sub on_read ($self, $buffref, $eof){

    unless ($$buffref =~ /(^\{)/ ){
        say "webbrowser detected";

        $self->close_now();
        $$buffref = "";
        $self->user->dismiss();
        return;
    }

    while( $$buffref =~ s/^(.*)\r\n// ) {
        my $msg_txt = $1;
        say "Received from ".$self->user->name." $msg_txt";
        my $msg_hash;
        try{
            $msg_hash = $json->decode($1);
            if ($msg_hash){
                $self->user->on_msg($msg_hash);
            }else{
                die;
            }
        }
        catch ($e){
            say $e;
        }
    }

    if( $eof ) {
        $self->user->dismiss();
        $self->close_now();
    }
    return 0;
}


# encodes a hash and sends it to this user's client
sub write ($self, $hash){
    my $msg = encode_json ( $hash );
    $msg = $msg."\r\n";
    say "sending to ".$self->user->name." $msg";
    $self->SUPER::write($msg);
}

sub set_user($self, $user){
    $self->{user} = $user;
}

sub user($self){
    return $self->{user};
}
1;
