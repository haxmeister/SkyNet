package SkyNet::DB;

use strict;
use warnings;
use DBI;
use SkyNet::Base;
use Data::Dumper;

sub new {
    my $package = shift;
    my %args = @_;
    my $self    = bless{
        'username' => $args{username},
        'password' => $args{password},
        'dsn'      => 'dbi:mysql:skynet',
    }, $package;

    return $self;
}

sub db_connect{
    my $self = shift;

    $self->{dbh} = DBI->connect(
        $self->{dsn},
        $self->{username},
        $self->{password},
        { RaiseError => 1, AutoCommit => 0 },
    ) or die "cannot connect to database".$DBI::errstr;
}

# returns an array ref
sub authenticate_user {
    my $self = shift;
    my $username = shift;
    my $password = shift;
    my $qstring = "SELECT * from users where username='".$username."' and password='".$password."';";
    print $qstring."\n";
    my $data = $self->query($qstring);
    print Dumper $data;
    return $data;
}

# returns an array of results
sub query{
    my $self = shift;
    my $sql = shift;
    my @data;
    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute();

    while(my $row = $sth->fetchrow_hashref()){
        push(@data, $row);
    }
    $sth->finish();
    return \@data;
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



