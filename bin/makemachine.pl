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

my %opts;

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
# v	be verbose
getopts('d:l:h:p:r:n:c:u:e:f:s:p:', \%opts);

if ( (!exists($opts{l})) || ($opts{l} !~ /.+/) ){
	print &usage;
	exit 1;
}
my $label = $opts{l};
my $hostname = $label.".us.positive-dedicated.net";
my $ram = $opts{r} || "1";
my $diskSize = $opts{d} || 39;
my $swapSize = $opts{s} || 1;
my $cpuShares = 10 * $ram;
my $cpuCount = 2;
my $templateID = 28;	# debian 6 amd64
my $netRateLimit = 100;


my $onappCredentialsFile = $ENV{'HOME'}."/.onapp_credentials";
my ($email,$key);
unless( -f $onappCredentialsFile ){
	print "OnApp requires that you log in with either a username and\n";	
	print "password or an email address and API key. You can avoid\n";
	print "being prompted by creating a file at ~/.onapp_credentials\n";
	print "with your username or email on the first line and password\n";
	print "or API key on the second\n\n";
	print "Enter username or email address:\n";
	$email = <>;
	print "Password or API key:\n";
	system('stty','-echo');
	$key = <>;
	system('stty','echo');
	print "\n";
}else{
	open(my $f, "<", "/home/avi/.onapp_credentials") or error("Error getting credentials from $onappCredentialsFile: $!");
	($email, $key) = (<$f>);
	close($f);
}
chomp($email);
chomp($key);

my $onapp = Net::OnApp->new(
	api_email => $email,
	api_key => $key,
	api_url => "cloudbase.us.positive-internet.com",
);



# If we need to create a user, check that we've got 
# all the right arguments and that the email address
# is unique
if( exists($opts{u}) ){
	my $username = $opts{u};
	foreach(qw/e f s u p/){
		unless( exists($opts{$_}) ){
			print "$_ is a required option when 'u' is passed";
			print &usage;
			exit 1;
		}
	}
	my %users = ${ $onapp->getUsers };
	foreach(keys(%users)){
		if ($_->{"email"} =~ /^$opts{"e"}$/i){
			error("User with email address $opts{'e'} already exists");
		}
	}
}

# Create a hash of 
# "short hostname" => "fqdn"
# so we know what already exists
my %hostnames = map { (split(/\./, $_))[0] => $_ } keys( %{ $onapp->getVMs } );


if ( exists(($hostnames{$label})) ){
	error("Machine with host name $hostname already exists");
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
	error("Error creating VM. OnApp said: \"$result->{status_description}\"");
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
print "Created. IP:$ipAddress\n";

sub error{
	my $message = shift;
	print STDERR "ERROR: ".$message."\n";
	exit 1;
}

sub usage{

my $string = <<EOF;

makemachine

Script for making OnApp virtual machines.

Usage:

makemachine <options>

VIRTUAL MACHINES:

 -l <label> 	Machine label. Mandatory
 -d <size>      Disk size (GB)
 -s <size>      Swap volume size (GB)
 -h <hostname>  Actually, fqdn. Defaults to 
                <label>.us.positive-dedicated.net
 -p <password>  Root password. Default is to autogenerate
 -r <size>      Amount of RAM (GB).
 -n <text>      Set the text of 'admin note'
 -c <text>      Set the text of the 'note'

USERS:

You can also create a user at the same time, and have that user
set as the owner of the virtual machine:

 -l <login>     Set the username. If this is set, it is expected
                that you wish to create a user, and so all the 
                rest of the user options become mandatory.
 -e <email>     User's email address. Must be unique on the system
 -f <name>      Forename
 -s <name>      Surname
 -p <password>  set password.

DEFAULTS:

Hostname        \$label."us.positive-dedicated.net"
Ram		1GB
Disk size	39GB
Swap size	1GB
CPU shares	10% for each GB of RAM
CPU Count	2
Template ID	28 (debian 6 amd64)
Net bandwidth	100MB

CREDENTIALS:

OnApp's API requires authentication, you may authenticate with one
of these two pairs of credentials:

 - username and password
 - email address and API key

You will be prompted for these on trying to create a VM unless you've
created a file at ~/.onapp_credentials. This file should have two 
lines, the first containing your username or email address  and the 
second your password or key. No extraneous whitespace or newlines
please.

VERSION:

This dates from 2012-02-01. You might find newer versions at

https://github.com/BigRedS/onapp

They might not be better.

EOF

}
