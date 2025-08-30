use v5.42;
use experimental qw(class);
no warnings 'experimental::class';

class SkyNet::Protocol::Actions v1.0.0;

field $user :reader :param;
field $server :reader;
field $db :reader;

ADJUST{
    $server = $user->server();
    $db     = $user->server->db();
}

# player spots broadcasting
method playerseen ($data){
    $data->{result} = 1;
    $server->broadcast($data, "seespots");
    return 0; # nothing for the user to do
}

my method get_playerlist($type){
    my $found = $db->list_status($type);
    my @list;
    my $now = time();

    foreach my $row (@$found){
        my $remaining = '--';
        $row->{type}  = $type;
        $remaining    = getTimeStr($row->{length} - ($now - $row->{ts}));

        push(@list, {
            'status'   => $row->{type},
            'name'     => $row->{name},
            'addedby'  => $row->{addedby},
            'remaining'=> $remaining,
            'notes'    => $row->{notes},
        });
    }

    return \@list;
}

# chat channel message broadcasting
method channel ($data) {
    my $res;

    unless ( $user->allowed->seechat ){
        $res->{action} = 'channel';
        $res->{result} = 0;
        $res->{error}  = "Not authorized to use alliance chat!";
        return $res;
    }

    $data->{result} = 1;
    $server->broadcast($data, "seechat");
    return 0; # nothing for the user to do
}

# check username and password of a user
method auth ($data){
    my $res;

    unless(exists $data->{username} and exists $data->{password} ){
        $res->{action} = "auth";
        $res->{result} = 0;
        $res->{error}  = "Missing credentials";
    }

    my $found = $db->validate_user($data->{username}, $data->{password});

    if ($found){
        $user->set_name( $found->{username} );
        foreach my $permission (keys %$found){
            next if $permission =~ /username|password|id/;
            try{
                $user->allowed->$permission($found->{$permission});
            }
            catch ($e){
                say $e;
            }
        }
        $user->set_loggedIn(1);
        $res->{action} = "auth";
        $res->{result} = 1;
        $server->broadcast_skynet_msg($data->{username}." has logged on..")
    }else{
        $res->{action} = "auth";
        $res->{result} = 0;
        $res->{error}  = "User credentials are invalid";
    }
    return $res;
}

# add new skynet user to the database
method sn_adduser ($data) {
    my $res;

    unless ( $user->allowed->manuser ){
        $res->{action} = 'sn_adduser';
        $res->{result} = 0;
        $res->{error}  = "Not authorized to add users!";
        return $res;
    }

    if ( $db->add_user($data) ){
        $res->{action} = 'skynetmessage';
        $res->{msg}    = $data->{username}." has been added to Skynet";
        $res->{result} = 1;
    }else{
        $res->{action} = 'sn_adduser';
        $res->{result} = 0;
        $res->{error}  = "Failed to add user to database";
    }

    return $res;
}

# remove a user's access
method removeuser ($data) {
    my $res;

    unless ( $user->allowed->manuser ){
        $res->{action} = 'removeuser';
        $res->{result} = 0;
        $res->{error}  = "Not authorized to remove users!";
        return $res;
    }

    if ( $db->remove_user($data) ){
        $res->{action} = 'skynetmessage';
        $res->{msg}    = $data->{username}." has been removed from Skynet";
        $res->{result} = 1;
    }else{
        $res->{action} = 'removeuser';
        $res->{result} = 0;
        $res->{error} = "Failed to remove user from database";
    }

    return $res;
}

# logoff the user by deleting from user list and closing connection
method logout ($data) {
    $user->dismiss;
}

# get the warranty status of a player
method playerstatus ($data) {
    my $res;

    unless ( $user->allowed->seestat ){
        $res->{action} = "playerstatus";
        $res->{result} = 0;
        return $res;
    }

    if ( my $row = $db->get_status($data->{name}) ) {
        if ($row->{'type'} == 1 ) { # KOS
            $res->{statustype} = 1;
            $res->{status}     = 'Player is KOS';

        } elsif ($row->{'type'} == 2) {
            $res->{statustype} = 3;
            $res->{status}     = 'Player is ALLY';

        } else {
            my $remaining = $row->{'length'} - ( time() - $row->{'ts'} );

            if ($remaining<60) { # Expired
                $res->{statustype} = 1;
                $res->{status}     = 'Payment expired!';
                $db->del_status($data->{name});
            } else {
                $res->{statustype} = 2;
                $res->{status}     = 'Paid - remaining: ' . getTimeStr($remaining);
            }
        }
    } else {
        $res->{statustype} = 3;
        $res->{status}     = 'Nothing found.';
    }

    $res->{action} = "playerstatus";
    $res->{name}   = $data->{name};
    $res->{result} = 1;

    return $res;
}

# make an announcement to all users
method announce ($data) {
    $data->{result} = 1;
    $server->broadcast($data, "seechat");
}

# return a list of all warranty statuses
method list ($data) {
    my $res;

    unless ( $user->allowed->seestat ){
        $res->{action} = "list";
        $res->{result} = 0;
        $res->{error}  = "You are not authorized to see the status list";
        return $res;
    }

    my $found = $db->list_status('ALL');
    my @list;
    my $now = time();
    foreach my $row(@$found){
        my $remaining = '--';

        if($row->{type} eq 0){
            next unless ( $user->allowed->seewarr );
            $row->{type} = "PAID";
            if (  ($row->{length} - ($now - $row->{ts})) < 1  ){next;}
            $remaining = getTimeStr($row->{length} - ($now - $row->{ts}));
        }
        elsif($row->{type} eq 1){
            next unless ( $user->allowed->seestat );
            $row->{type} = "KOS";
            $remaining = getTimeStr($row->{length} - ($now - $row->{ts}));
        }
        elsif($row->{type} eq 2){
            next unless ( $user->allowed->seestat);
            $row->{type} = "ALLY";
        }


        push(@list, {
            'status'   => $row->{type},
            'name'     => $row->{name},
            'addedby'  => $row->{addedby},
            'remaining'=> $remaining,
            'notes'    => $row->{notes},
        });
    }

    if (@list){
        $res->{action} = 'showlist';
        $res->{result} = 1;
        $res->{list}   = \@list;
    }else{
        $res->{action} = "list";
        $res->{result} = 0;
        $res->{error}  = "list is empty..",
    }


    return $res;
}

# return a list of all players that have warranties
method listpayment ($data) {
    my $res;

    unless ( $user->allowed->seestat ){
        $res->{action} = "listpayment";
        $res->{result} = 0;
        $res->{error}  = "You are not authorized to see payment statuses";
        return $res;
    }

    $res = $self->&get_playerlist("PAID");


    if ( @{$res->{list}} ){
        $res->{action} = "showlist";
        $res->{result} = 1;
    }else{
        $res->{action} = "listpayment";
        $res->{result} = 0;
        $res->{error}  = "list is empty..";
    }
    return $res;
}

# return a list off all players with KOS status
method listkos ($data) {
    my $res;

    unless ( $user->allowed->seestat ){
        $res->{action} = "listkos";
        $res->{result} = 0;
        $res->{error}  = "You are not authorized to see KOS statuses";
        return $res;
    }

    $res->{list} = $self->&get_playerlist("KOS");

    if ( @{$res->{list}} ){
        $res->{action} = "showlist";
        $res->{result} = 1;
    }else{
        $res->{action} = "listkos";
        $res->{result} = 0;
        $res->{error}  = "list is empty..";
    }
    return $res;
}

# return a list of all players with ALLY status
method listallies ($data) {
    my $res;

    unless ( $user->allowed->seestat ){
        $res->{action} = "listallies";
        $res->{result} = 0;
        $res->{error}  = "You are not authorized to see ALLY statuses";
        return $res;
    }

    $res->{list} = $self->&get_playerlist("ALLY");

    if ( @{$res->{list}} ){
        $res->{action} = "showlist";
        $res->{result} = 1;
    }else{
        $res->{action} = "listallies";
        $res->{result} = 0;
        $res->{error}  = "list is empty..";
    }
    return $res;
}

method addpayment ($data) {
    my $res;
    my @match = $data->{length} =~ /^(\d+)([dhm]?)$/;

    if(! @match){
        $res->{'result'} = 0;
        $res->{'error'}  = "Invalid time period parameter.";
    }else{
        my $length = $match[0];
        my $interval = $match[1];

        if ($interval eq 'd'){
            $length  *= 86400;
        }elsif($interval eq 'h'){
            $length *= 3600;
        }else{
            $length *= 60;
        }
        $data->{length} = $length;
    }

    if ( $db->add_payment($user->name, $data) ){
        $res->{action} = "addpayment";
        $res->{result} = 1;
        $server->broadcast_skynet_msg($data->{name}." purchased a warranty from ".$user->name);
    }else{
        $res->{action} = "addpayment";
        $res->{result} = 0;
        $res->{error}  = "could not add warranty to db"
    }

    return $res;
}

method removepayment ($data) {
    my $res;

    unless ( $user->allowed->manstat ){
        $res->{action} = "removepayment";
        $res->{result} = 0;
        $res->{error}  = "You are not authorized to see ALLY statuses";
        return $res;
    }

    if ( $db->del_status($data->{name}) ){
        $res->{action} = "removepayment";
        $res->{result} = 1;
    }else{
        $res->{action} = "removepayment";
        $res->{result} = 0;
        $res->{error}  = "Could not remove payment status";
    }
    return $res;
}

method addkos ($data) {
    my $res;

    unless ( $user->allowed->manstat ){
        $res->{action} = "addkos";
        $res->{result} = 0;
        $res->{error}  = "You are not authorized to add KOS status";
        return $res;
    }

    if( $db->add_kos($user->name, $data) ){
        $res->{action} = "addkos";
        $res->{result} = 1;
        $server->broadcast_skynet_msg($data->{name}." has been labeled KOS by ".$user->name."!");
    }else{
        $res->{action} = "addkos";
        $res->{result} = 0;
        $res->{error}  = "Could not add KOS status";
    }

    return $res;
}

method removekos ($data) {
    my $res;
    unless ( $user->allowed->manstat ){
        $res->{action} = "removekos";
        $res->{result} = 0;
        $res->{error}  = "You are not authorized to remove KOS status";
        return $res;
    }

    if ( $db->del_status($data->{name}) ){
        $res->{action} = "removekos";
        $res->{result} = 1;
    }else{
        $res->{action} = "removekos";
        $res->{result} = 0;
        $res->{error}  = "Could not remove kos status";
    }
    return $res;
}

method addally ($data) {
    my $res;
    my $now = time();

    unless ( $user->allowed->manstat ){
        $res->{action} = "addally";
        $res->{result} = 0;
        $res->{error}  = "You are not authorized to add ally status";
        return $res;
    }

    if ( $db->add_ally( $user->name, $data) ){
        $res->{action} = "addally";
        $res->{result} = 1;
        $server->broadcast_skynet_msg($data->{name}." has been labeled ALLY by ".$user->name."!");
    }else{
        $res->{action} = "addally";
        $res->{result}   = 0;
        $res->{error}    = "unable to add ALLY status";
    }

    return $res;
}

method removeally ($data) {
    my $res;
    unless ( $user->allowed->manstat ){
        $res->{action} = "removeally";
        $res->{result} = 0;
        $res->{error}  = "You are not authorized to remove ALLY status";
        return $res;
    }

    if ( $db->del_status($data->{name}) ){
        $res->{action} = "removeally";
        $res->{result} = 1;
    }else{
        $res->{action} = "removeally";
        $res->{result} = 0;
        $res->{error}  = "Could not remove ally status";
    }
    return $res;
}

### private methods



sub getTimeStr($secs){
    if ($secs<0) {
        return "--";
    }
    my $days = int($secs / 86400);
    my $rem = $secs - ($days*86400);
    my $hours = int($rem / 3600);
    $rem = $rem - ($hours * 3600);
    my $min = int($rem / 60);
    return sprintf("%dd %02dh %02dm", $days, $hours, $min);
}
1;
