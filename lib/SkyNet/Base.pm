package SkyNet::Base;

use strict;
use warnings;
use JSON;
use Term::ANSIColor;
use Exporter;
our @EXPORT = qw(decode encode log_this);


# decode the json message with error protection for bad data
# returns a ref to the new data structure or an empty string if it fails
sub decode{
    my $self = shift;
    my $msg  = shift;
    my $ref  = '';

    eval { $ref = decode_json($msg); 1; };
    return $ref;
}

# encode a data structure to json
sub encode{
    my $self = shift;
    my $data = shift;

    return encode_json($data);
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

