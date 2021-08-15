package SkyNet::DB;

use strict;
use warnings;
use DBI;

sub new {
    my $package = shift;
    my $args    = shift;
    my $self    = bless {
        'server'      => $args->{'server'},
        'db_username' => $args->{'db_username'},
        'db_password' => $args->{'db_password'},
        'dsn'         => 'dbi:mysql:SkyNet',
    }, $package;

    $self->{'db'} = DBI->connect( $self->{dsn}, $self->{db_username}, $self->{db_password}, { RaiseError => 1, AutoCommit => 0 }, ) or print STDERR $DBI::errstr;

    return $self;
}

sub add_user {
    my $self = shift;
}

sub remove_user {
    my $self = shift;
}

sub change_perms {
    my $self = shift;
}

sub get_user {
    my $self = shift;
}

sub confirm_login {
    my $self = shift;
}

1;



