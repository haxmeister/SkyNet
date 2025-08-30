use v5.42;
use experimental qw(class);
no warnings 'experimental::class';

class SkyNet::DB v1.0.0;
use DBI;
use Util::H2O;

field $name :param;
field $dbh :reader;
field $lists;

ADJUST{
    $lists = h2o {
        ALL    => "SELECT * FROM playerlist ORDER BY type, name",
        PAID   => "SELECT * FROM playerlist WHERE type=0 ORDER BY name",
        KOS    => "SELECT * FROM playerlist WHERE type=1 ORDER BY name",
        ALLY   => "SELECT * FROM playerlist WHERE type=2 ORDER BY name",
    };
}

# create and/or connect to sqlite database
ADJUST{
    $dbh  = DBI->connect(
        "dbi:SQLite:dbname=$name"."db","","",
        {
            AutoCommit => 1,
        },
    ) or die $DBI::errstr;
}


# initialize database tables
ADJUST{
    my $user_table = q{
        CREATE TABLE IF NOT EXISTS users (
            username VARCHAR(50) PRIMARY KEY,
            password VARCHAR(50) NOT NULL,
            seespots INTEGER DEFAULT 0,
            seechat INTEGER DEFAULT 0,
            manuser INTEGER DEFAULT 0,
            manwarr INTEGER DEFAULT 0,
            manstat INTEGER DEFAULT 0,
            seestat INTEGER DEFAULT 0,
            seewarr INTEGER DEFAULT 0,
            addbot INTEGER DEFAULT 0

            );
    };

    $dbh->do($user_table) or die $dbh->errstr or die $dbh->errstr;

    my $playerlist_table = q{
        CREATE TABLE IF NOT EXISTS playerlist (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type INTEGER NOT NULL,
            ts INTEGER NOT NULL,
            name VARCHAR(50) PRIMARY KEY,
            length INTEGER NOT NULL,
            addedby VARCHAR(50) NOT NULL,
            notes VARCHAR(50)
        );
    };

    $dbh->do($playerlist_table) or die $dbh->errstr;

    # add an admin user
    my $sql = "INSERT OR REPLACE INTO users (username, password, seespots, seechat, manuser, manwarr, manstat, seestat, seewarr, addbot) VALUES(?,?,?,?,?,?,?,?,?,?)";
        my $sth = $dbh->prepare($sql);
        $sth->execute(
                'admin',
                'skynet2025',
                1, # seespots
                1, # see chat
                1, # manage users
                1, # manage warranties
                1, # manage statuses
                1, # see statuses
                1, # see warranties
                1,  # add bots
            );
        $sth->finish();

}

method validate_user($username, $password){
    my $result = 0;
    my $sth = $dbh->prepare("SELECT * from users where username = ? and password = ?");
    $sth->execute($username, $password);

    $result = $sth->fetchrow_hashref();
    $sth->finish();

    # when the login successful
    if ($result){
        print STDERR $username." has logged in\n";
        return $result;
    }else{
        return 0;
    }
}

method add_user($data){
    my $sth = $dbh->prepare("INSERT OR REPLACE INTO users (username, password, seespots, seechat, manuser, manwarr, manstat, seestat, seewarr, addbot) VALUES(?,?,?,?,?,?,?,?,?,?)");
    $sth->execute(
        $data->{username},
        $data->{password},
        $data->{seespots},# seespots
        $data->{seechat}, # see chat
        $data->{manuser}, # manage users
        $data->{manwarr}, # manage warranties
        $data->{manstat}, # manage statuses
        $data->{seestat}, # see statuses
        $data->{seewarr}, # see warranties
        $data->{addbot},  # add bots
    );

    return $sth->finish();
}

method remove_user($data){
   my $sth = $dbh->prepare("DELETE FROM users WHERE username=?");
    $sth->execute($data->{username});
    return $sth->finish();
}

method get_status($name){
    my $sth = $dbh->prepare("SELECT * FROM playerlist WHERE name = ?");
    $sth->execute($name);
    my $found = $sth->fetchrow_hashref();
    $sth->finish();
    return $found;
}

method del_status($name){
    my $sth = $dbh->prepare("DELETE FROM playerlist WHERE name=?");
    $sth->execute($name);
    return $sth->finish();
}

method list_status($type){
    my $sth = $dbh->prepare($lists->$type);
    $sth->execute();
    my @found;
    while( my $row = $sth->fetchrow_hashref() ){
        push (@found, $row);
    }
    $sth->finish();
    return \@found;
}


sub getTimeStr {
    my $secs = shift;
    if ($secs < 0) {
        return "--";
    }
    my $days = int($secs / 86400);
    my $rem = $secs - ($days * 86400);
    my $hours = int($rem / 3600);
    $rem = $rem - ($hours * 3600);
    my $min = int($rem / 60);
    return sprintf("%dd %02dh %02dm", $days, $hours, $min);
}
