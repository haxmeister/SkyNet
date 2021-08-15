package SkyNet::DBI;

use strict;
use warnings;

sub new {
    my $package = shift;
    my $self    = bless {

    }, $package;

    return $self;
}

sub add_user      { }
sub remove_user   { }
sub change_perms  { }
sub get_user      { }
sub confirm_login { }


1;

