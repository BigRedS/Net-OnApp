#! /usr/bin/perl

use 5.010;
use strict;
use lib '/home/avi/bin/onapp/lib/';
use OnApp::API;
use Data::Dumper;

open(my $f, "<", "/home/avi/.onapp_credentials") or die "Error getting credentials";
my ($email, $key) = (<$f>);
close($f);

chomp($email);
chomp($key);

my $vm = OnApp::API->new(
	api_email => $email,
	 api_key  => $key,
	api_url   => "cloudbase.us.positive-internet.com",
);

my $loadacrap = $vm->getVMs(
	andFilter => {
		hostname => "gin",
	},
);

#print Dumper($loadacrap);
my %hash = %{$loadacrap};
foreach(keys(%hash)){
	say;
}




