#!/usr/bin/env perl

use warnings;
use strict;
use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin/lib";
use JSON;

my $json = JSON->new->pretty->allow_nonref;
my %hash;
my %other;

$hash{name} = "jsoh";
$hash{age} = 44;
print encode_json( \%hash)."\n\n";;

$other{body} = 'fat';
$other{feet} = 11;

%hash = %other;
print encode_json(\%hash)."\n\n";


