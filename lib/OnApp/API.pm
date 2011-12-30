#! /usr/bin/perl  

package OnApp::API;

use strict;
#use warnings;
use 5.010;
use Carp;
use LWP::UserAgent;
use JSON;
use Data::Dumper;

my $VERSION;
$VERSION=0.20111102;

=pod

=head1 NAME

OnApp::API - Perlish interface to OnApp API

=head1 SYNOPSIS

  use OnApp::API;
  my $vm = OnAPP::API->(
         api_email => $email,
	 api_key   => $key,
	 api_url   => $url,
  );

  my $hashOfVms = $vm->getVMs();

=head1 CONSTRUCTOR AND STARTUP

=head3 new()

Creates and returns an OnApp::API object. Expects authentication and endpoint details:

  my $vm = OnApp::API->new)
        api_email => "name@domain.com",
        api_key	  => "supersecretkey",
        api_url   => "url.of.the.onapp.box",
  );

You can, if you prefer, supply C<api_email> with a web UI username and C<api_key> with a web UI password.

=cut


sub new{
	my $class = shift;
	my %params = @_;
	my $self = {};

	my($apiUser,$apiPass);
	if(exists($params{'api_email'})){
		$apiUser = $params{'api_email'};
		$apiPass = $params{'api_key'};
	}elsif(exists($params{'api_user'})){
		$apiUser = $params{'api_user'};
		$apiPass = $params{'api_pass'};
	}else{
		Carp::croak("Neither 'api_email' nor 'api_user' passed to constructor");
	}

	my $apiURL;
	if(exists($params{'api_url'})){
		$apiURL = $params{'api_url'};
	}else{
		Carp::croak("'api_url' not passed to constructor");
	}

	my $apiUrlPort;
	if(exists($params{'api_url_port'})){
		$apiUrlPort = $params{'api_url_port'};
	}else{
		$apiUrlPort = "80";
	}

	my $apiRealm = "OnApp API Authentication";
	my $headers = HTTP::Headers->new();
	$headers->header('accept' => 'application/json');
	$headers->header('content-type' => 'application/json');

	
	my $userAgent = LWP::UserAgent->new(
	        default_headers => $headers,
	);
	my $apiLocation = $apiURL.":".$apiUrlPort;
	$userAgent->credentials($apiLocation, $apiRealm, $apiUser, $apiPass);
	$self->{'_userAgent'} = $userAgent;
	$self->{'_url'} = "http://$apiURL";

	bless($self);
	return($self); 
}

		

=head1 METHODS

=head2 VMs

=head3 getVMs()

Returns a reference to a hash-of-hashes whose keys are the hostnames of the VMs:

 my $vms = $vm->getVMs;

 $vms->{'hostname'}

=cut

sub getVMs(){
	my $self = shift;
	my %args = @_;
	my $url = $self->_getUrl("get", "vms");
	my $ref = $self->_getRef($url);
	my $ref = $self->_tidyData($ref);
	return $ref;
}

=head3 createVM();
> *cpus	 		Number of CPUs assigned to the VM.
> *cpu_shares		Set CPU priority for this VM.
> *Hostname		Set the host name for this VM.
> *label		User-friendly VM description.
> *primary_disk_size	Set the disk space for this VM. in GB.
> *swap_disk_size	Set swap space. There is no swap disk for Windows-based VMs.
> primary_network_id	The ID of the primary network. Optional parameter.
> required_automatic_backup	Set 1 if you need automatic backups.
> rate_limit		Set max port speed. Optional parameter: if none set, the system sets port speed to unlimited.
> *required_ip_address_assignment	Set 1 if you wish the system to assign an IP automatically
> *required_virtual_machine_build	Set 1 to build VM automatically
> admin_note		Enter a brief comment for the VM. Optional parameter.
> Note			A brief comment a user can add to a VM.
> *template_id	 	The ID of a template from which a VM should be built
> hypervisor_group_id	The ID of the hypervisor zone in which the VM will be created. Optional: if no hypervisor zone is set, the VM will  be built in any available hypervisor zone.
> hypervisor_id		The ID of a hypervisor where the VM will be built.
> initial_root_password Root password. [\w\-\_]{6,32} created if not supplied

=cut

sub createVM(){
	my $self = shift;
	my %args =@_;
	my $url = $self->_getUrl("get", "vms");
	# set some defaults:
	my %params = (
		required_automatic_backup => "0",
		required_ip_address_assignment => "1",
		required_virtual_machine_build => "1",
	);

	%params = (%params, %args);
	my @requiredParams = qw/cpus cpu_shares Hostname label primary_disk_size swap_disk_size required_ip_address_assignment required_virtual_machine_build template_id/;
	foreach my $param (@requiredParams){
		Carp::croak "Paramater '$param' not passed to createVM " unless(exists($params{$param}));
	}

	my $json = $self->_makeJson(\%params);
	my $json = '{"virtual_machine":'.$json.'}';

	print $json;
	say "x " x20;
	my $url = $self->_getUrl("set", "vms");
	my $response = $self->_postJson(\%params, $url);
	print $response->as_string;
	return;	

}

=head2 TEMPLATES

=head3 getTemplates()

Returns a hashref describing the templates. This is a hash-of-hashes, where the keys
are the ID of the template described in the constituent hashes.

=cut

sub getTemplates{
	my $self = shift;
	my %args = @_;
	my $url = $self->_getUrl("get", "templates");
	my $ref = $self->_getRef($url);
	my $return = $self->_tidyData($ref, 'id');
	return $return;
}

=head1 PRIVATE METHODS

Don't use these.

=head2 _tidyData()

Makes the data structure more sane. The API, when passed through C<JSON::decode_json()>, 
produces an array of hashrefs. Each of those hashes itself contains a single hashref
describing the elements being returned.

This takes that structure and rearranges it into a single hash of hashrefs. The keys of
the parent hash are the value of a single key from each of the constituent hashes, defined 
by the scond parameter to C<tidyData>:

  $ref $self->tidyData($ref, "hostname");

will rearrange the $ref structure such that 

  keys(%{ $ref });

will return a list of hostnames.

=cut

sub _tidyData{
	my $self = shift;
	my $ref = shift;
	my $idField = shift;
	my @machines = @{ $ref };
	my %machine;
	my %data;
	foreach my $m (@machines){
		%machine = %{$m};
		foreach my $virtual_machine (keys(%machine)){
			my $hostname = $machine{$virtual_machine}{$idField};
			$data{$hostname} = $machine{$virtual_machine};
		}
	}
	my $return = \%data;
	return $return;
}

sub _untidyData{
	my $self = shift;
	my $ref = shift;
	my $extraName = shift;
	my @array = {
		$extraName => $ref
	};
	return \@array;
}

#	if( exists($args{'andFilter'}) || exists($args{'orFilter'}) ){
#		$return = $self->_applyFilter(
#			data      => $return,
#			andFilter => $args{'andFilter'},
#		);
#	}
#	return $return;

=head2 _applyFilter(), _applyAndFilter(), _applyOrFilter()

This is currently not used. It seems a bit pointless trying to provide a
generic filter here when it might as well be done outside of the module
in a more specific way, or by the API itself (which it isn't).

_applyFilter is passed two hashrefs:

   data:      some data to filter
   andFilter: a set of filtering criteria

It calls _applyAndFilter (and will, in the future, call _applyOrFilter)
to do the filtering. Currently, it's a bit crude. The expectation is that
C<data> will be a hash of hashes. Each of its constituent hashes is kept if, 
and only if, each of its keys mentioned in C<andFilter> case-insensitively
matches the corresponding value in C<andFilter>

=cut

sub _applyFilter{
	my $self = shift;
	my %args = @_;
	my $data = $args{'data'};

	if ( exists($args{'andFilter'}) ){
		$data = $self->_applyAndFilter(
			data	=> $data,
			filter	=> $args{'andFilter'}
		);
	}

	return $data
}


sub _applyAndFilter{
	my $self = shift;
	my %args = @_;
	my %data = %{ $args{'data'} };

	my %filter = %{ $args{'filter'} };

	return $args{'data'} unless $args{'filter'};
	foreach my $element ( keys(%data) ){
		foreach my $condKey ( keys(%filter) ){
			my $condVal = $filter{$condKey};
			if( exists($data{$element}{$condKey}) ){
				delete( $data{$element} ) unless $data{$element}{$condKey} =~ /$condVal/i;
			}else{
			}
		}
	}
	my $return = \%data;
	return $return;
}

sub _applyOrFilter{
	my $self = shift;
	my %args = @_;
	my %data = %{ $args{'data'} };
	my %filter = %{ $args{'filter'} };

	return $args{'data'} if !%filter;

	my %keepData;
	my %data;
	foreach my $element ( keys(%data) ){
		foreach my $condKey ( keys(%filter) ){
			my $condVal = $filter{$condKey};
			if( exists($data{$element}{$condKey}) ){
				if( $data{$element}{$condKey} =~ /$condVal/i ){
					$keepData{$element} = $data{$element}
				}
			}
		}
	}
	my $return = \%keepData;
	return $return;
}

=head2 _getRef()

Given a full URL (as returned by C<_getURL> ), returns a hashref containing
The data.

=cut

sub _getRef{
	my $self = shift;
	my $url = shift;
	my $response = $self->{_userAgent}->get($url);
	my $body = $response->content;
	my $hash = decode_json($body);
	return $hash;
}


sub _postJson{
	my $self = shift;
	my $ref = shift;
	my $url = shift;

	my $json = $self->_makeJson($ref);
	$self->{_userAgent}->default_header("Content-type" => "application/application/json");	
	$self->{_userAgent}->default_header("Accept" => "application/json");
	my $response = $self->{_userAgent}->post($url, $json);
	return $response;
}



=head3 _makeJson()

Given a hashref, creates some JSON for passing to OnApp.

=cut

sub _makeJson{
	my $self = shift;
	my $ref = shift;
	my $json = encode_json($ref);
	return $json;
}

=head3 _postJson()
Given a hashref, passes it to _makeJson to JSONify it and them POSTs it
to the relevant API URL
=cut

=head2 _getUrl()
Used to create URLs from easy-to-remember names. For example, to get
the correct URL for the API to return a list of users, you can do

  _getURL("get", "users");

These URLs are then passed to C<_getRef>.

=cut

sub _getUrl{
	my $self = shift;
	my $getOrSet = shift;
	my $what = shift;
	my %uris = (
		get => {
			users	=> '/users.json',
			vms	=> '/virtual_machines.json',
			templates => '/templates.json',
		},
		set => {
			users	=> '/users.json',
			vms	=> '/virtual_machines.json',
			templates => '/templates.json',
		},
	);
	my $uri = $uris{$getOrSet}{$what};
	my $url = $self->{'_url'}.$uri;
	return $url;

	my $url = shift;
	my $response = $self->{_userAgent}->get($url);
	my $json = $response->content;
	my $data = from_json($json);
	return $data;

}


=head2 _getHash()

Deprecated already, in favour of C<_getRef>. 'cause references are cool.

=cut

sub _getHash(){
	my $self = shift;
	my %args = @_;
	my $url = $self->{'_url'}."/users.json";
	print "<$url>";
	my $reference = $self->_getRef($url);
	unless(%args){
		return $reference;
	}
}

=head1 SEE ALSO

L<http://cdn.onapp.com/files/docs/onapp_cloud_2-3_api_guide_v1-3.pdf>

=head1 COPYRIGHT

Copyright 2011 Avi Greenbury (bigreds)

All right reserved. This program is free software; you can redistribute it and/or modify 
it under the same terms as Perl itself or, at your option, under the BSD license.

=head1 AUTHOR
  bigreds (Avi Greenbury) bigreds@cpan.org

=cut

1;
