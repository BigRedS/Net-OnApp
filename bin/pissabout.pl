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
        api_key   => $key,
	api_url   => "cloudbase.us.positive-internet.com",
);

my $t = $vm->getTemplates;
my %templates = %{ $t };
#print Dumper(%templates);
my $templateID;
foreach(keys(%templates)){
	if ($templates{$_}{label} =~ /^Debian 6\.0 x64$/i){
		$templateID = $_;
	}
}

$vm->createVM(
	cpus	=> 1,
	cpu_shares => 2,
	Hostname => "avitest",
	label => "avi testing",
	primary_disk_size => 8,
	swap_disk_size => 1,
	rate_limit => 100,
	admin_note => "do-wop",
	Note => "doo-wop",
	template_id => $templateID,
);
