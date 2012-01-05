#! /usr/bin/perl

# makeserver.pl

# Script for building OnApp VMs with some degree of autonomy.

use lib "/home/avi/bin/onapp/lib";

use Net::OnApp;
use strict;
use warnings;
use Getopt::Std;
use Data::Dumper;
use 5.010;

open(my $f, "<", "/home/avi/.onapp_credentials") or die "Error getting credentials";
my ($email, $key) = (<$f>);
close($f);

chomp($email);
chomp($key);

my $onapp = Net::OnApp->new(
	api_email => $email,
	api_key => $key,
	api_url => "cloudbase.us.positive-internet.com",
);



# d	disk size (GB)
# s	swap volume size (GB)
# l	label
# h	hostname
# p	root password
# r	ram (GB)
#  {cpu share}% = 10 * {RAM}GB
#  cpus = 2
# n	admin note 
# c	normal note (comment)
# Creating a user, too:
# u	login name (username is created if this is set)
# e	email address
# f	first name
# s	surname
# p	password

my %opts;
getopts('d:l:h:p:r:n:c:u:e:f:s:p:', \%opts);

if ( (!exists($opts{l})) || ($opts{l} !~ /.+/) ){
	print &usage;
	exit 0;
}
my $label = $opts{l};
my $hostname = $label.".us.positive-dedicated.net";
my $ram = $opts{r} || "1";
my $diskSize = $opts{d} || 8;
my $swapSize = $opts{s} || 1;
my $cpuShares = 10 * $ram;
my $cpuCount = 2;
my $templateID = 28;	# debian 6 amd64
my $netRateLimit = 100;

if( exists($opts{u}) ){
	my $username = $opts{u};
	foreach(qw/e f s u p/){
		unless( exists($opts{$_}) ){
			print "$_ is a required option when 'u' is passed";
			print &usage;
			exit 1;
		}
	}
}


my %hostnames = map { (split(/\./, $_))[0] => $_ } keys( %{ $onapp->getVMs } );

if ( exists(($hostnames{$label})) ){
	print STDERR "Machine with host name $hostname already exists\n";
	exit 1;
}

my $result = $onapp->createVM(
	cpus		=> $cpuCount,
	cpu_shares 	=> $cpuShares,
	hostname	=> $hostname,
	label		=> $label,
	primary_disk_size => $diskSize,
	swap_disk_size  => $swapSize,
	rate_limit	=> $netRateLimit,
	admin_note	=> $opts{n},
	note		=> $opts{c},
	template_id	=> $templateID,
	memory		=> $ram
);

if(exists($result->{status})){
	print STDERR "Error creating VM. OnApp said \"$result->{status_description}\"\n";
	exit 1;
}

my $vmID = $result->{id};

if (exists($opts{u})){

	# u	login name (username is created if this is set)
	# e	email address
	# f	first name
	# s	surname
	# p	password

	my $newuser = $onapp->createUser(
		email      => $opts{e},
		first_name => $opts{f},
		last_name  => $opts{s},
		login      => $opts{u},
		password   => $opts{p},
	);
	my $userID;
	if( exists( $newuser->{status_code}) ){ 
		print STDERR "Error creating user. OnApp said \"$newuser->{status_description}\"\n";
	}else{
		$userID = $newuser->{id};
	}	
	my $result = $onapp->chownVM(
		virtual_machine_id => $vmID,
		user_id	           => $userID,
	);
	if (exists( $onapp->{status_code})){
		print STDERR "Error chowning VM \"$vmID\" to User \"$userID\". OnApp said \"$result->{status_description}\"\n";
	}
}

my $ipAddress = $result->{ip_addresses}[0]->{ip_address}->{address};
print $ipAddress;

sub usage{
	return "idiot.\n";
}
