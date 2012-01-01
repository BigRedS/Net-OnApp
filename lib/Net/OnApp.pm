#! /usr/bin/perl  

package Net::OnApp;

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

Net::OnApp - Perlish interface to OnApp API

=head1 SYNOPSIS

Net::OnApp is a perl interface to OnApp's API

  use OnApp::API;
  my $vm = OnAPP::API->(
         api_email => $email,
	 api_key   => $key,
	 api_url   => $url,
  );

  my $hashOfVms = $vm->getVMs();

  my $response = $vm->createVM(
        cpus    => 1, 
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

=head1 RETURN VALUES

Each of the C<create> methods returns a hashref. On success, the hashref is equivelent
to what you'd get out of a C<getWhatever> call. On failure, you get a hashref containing 
info which might be handy for debugging:

=over 4

=item C<status_code> HTTP numerical status code

=item C<status> HTTP standard description for the HTTP status code

=item C<status_description> OnApp's explanation of the HTTP status code.

=item C<requested_url> The URL requested

=item C<json> The JSON sent

=item C<response_objct> => The response object as returned by the C<LWP::UserAgent> object 
used to POST the data.

=back

So if you get a response cointaining a C<status> key, then something's gone wrong.

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
	$userAgent->agent("Avi's OnAPP::API/$VERSION ");
	$self->{'_userAgent'} = $userAgent;
	$self->{'_url'} = "http://$apiURL";

	bless($self);
	return($self); 
}

		

=head1 METHODS

=head2 Users

=head3 Get the list of users : getUsers

Returns a reference to a hash-of-hashes whose keys are the usernames of the users. 

=cut

sub getUsers{
	my $self = shift;
	my $url = $self->_getUrl("get", "users");
	my $ref = $self->_getRef($url);
	my $ref = $self->_tidyData($ref, 'login');
	return $ref;
}

=head3 Get user details : getUserInfo()

Returns a reference to a hash describing the user whose ID it's passed:

  my $ref = $onapp->getUserInfo($id);


=cut

sub getUserInfo{
	my $self = shift;
	my %args = @_;
	my $id = shift;
	my $url = $self->_getUrl("get", "user");
	$url.=$id.".json";
	my $response = $self->_get($url);
	if ($response->{status_code} =~ /^2/){
		my $vmInfo = $response->{'content'};
		my $ref = $self->_makeRef($vmInfo);
		my $ref = $ref->{'user'};
		return $ref;
	}else{
		return $response;
	}
}

=head3 Create a user : createUser()

Creates a user based on the hashref it's passed. 

Mandatory fields:

=over 4

=item C<email> user’s email address

=item C<first_name> user’s first name

=item C<last_name> user’s last name

=item C<login> login of the user. It can consist of 4-40 characters, letters [A-Za-z], digits [0-9], dash [ - ], lower dash [ _ ], [@]. You can use both lower- and uppercase letters

=item C<password> user’s password. (min – 6 characters)

=item C<password_confirmation> confirmation of the password (retype the password)

=back

If C<password_confirmaton> is not passed, it is automatically set to the value of C<password>. If it is 
passed and is empty, it will be passed to OnApp as such and you'll probably get an error in return.

Optional fields:

=over 4

=item C<role> assigns a role to a user

=item C<time_zone> time zone of the user. Set by default

=item C<locale> local of the user. Set by default

=item C<status> user’s status (active, suspended, etc)

=item C<billing_plan_id> set by default, if not selected

=item C<role_ids> ID of the role, assigned to the user

=item C<user_group_id> ID of the group, to which the user is attached

=item C<suspend_after_hours> time in hours, after which the user will be suspended

=item C<suspend_at> time in [YYYY][MM][DD] T[hh][mm][ss]Z format, when the user will be suspended

=back

=cut

sub createUser{
	my $self = shift;
	my %args =@_;
	my $url = $self->_getUrl("get", "vms");

	$args{'password_confirmation'} = $args{'password'} unless exists($args{'password_confirmation'});
	
	my %params;
	%params = (%params, %args);
	my @requiredParams = qw/email first_name last_name login password password_confirmation/;
	foreach my $param (@requiredParams){
		Carp::croak "Paramater '$param' not passed to createVM " unless(exists($params{$param}));
	}

	my $url = $self->_getUrl("set", "users");
	my $response = $self->_postJson(
		ref => \%params,
		url => $url,
		container => "user",
	);

	if ($response->{status_code} =~ /^2/){
		my $vmInfo = $response->{'content'};
		my $ref = $self->_makeRef($vmInfo);
		my $ref = $ref->{'user'};
		return $ref;
	}else{
		return $response;
	}

}

=head3 View user's statistics - getUserStats()

Pass a user id as the only argument, get usage and costing stats for a user. 

Returns a hash:

 edge_group_cost' => '0',
 vm_cost' => '2.44185590744019',
 total_cost' => '2.44185590744019',
 user_resources_cost' => '0',
 vm_stats' => [
	{  
		 usage_cost' => '0',
		 vm_resources_cost' => '2.44185590744019',
		 total_cost' => '2.44185590744019',
		 virtual_machine_id' => 10 
	}  
 ], 
 monit_cost' => '0',
 backup_cost' => '0',
 storage_disk_size_cost' => '0',
 template_cost' => '0'


=cut

sub getUserStats{
	my $self = shift;
	my %args = @_;
	my $id = shift;
	my $url = $self->_getUrl("get", "user");
	$url.=$id."/user_statistics.json";
	return $self->_simpleGet($url);
}

=head3 See user's monthly bills : getUserBill()

Returns an arrayref containing one hashref per month. Each constituent hashref
has two keys: C<month> and C<cost>. 

C<month> is a count of months, where '1' is the first billed month, not January 
or February.

C<cost> is the total billed cost - the montly price plus any usage costs.

=cut

sub getUserBill{

	my $self = shift;
	my %args = @_;
	my $id = shift;
	my $url = $self->_getUrl("get", "user");
	$url.=$id."/monthly_bills.json";
	return $self->_simpleGet($url);
}

=head3 See VMs of a particular user : getUserVMs

Takes a user ID as an argument, returns an array of hashes describing that
user's virtual machines. Probably.

=cut

sub getUserVMs{
	my $self = shift;
	my %args = @_;
	my $id = shift;
	my $url = $self->_getUrl("get", "user");
	$url.=$id."/virtual_machines.json";
	my $ref = $self->_simpleGet($url);
}


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
	my $ref = $self->_tidyData($ref, 'hostname');
	return $ref;
}

=head3 createVM();

Creates a virtual machine according to the parameters in the hashref passed as an argument. Items
with asterisks are mandatory, wording below is essentially verbatim from the API docs.

There's some stupid capitalisation going on in the docs - everything must be lower case.

I've set three defaults:

 required_automatic_backup => "0",
 required_ip_address_assignment => "1",
 required_virtual_machine_build => "1",

Mandatory fields:

=over 4

=item C<cpus> Number of CPUs assigned to the VM.

=item C<cpu_shares> Set CPU priority for this VM.

=item C<hostname> Set the host name for this VM.

=item C<label> User-friendly VM description.

=item C<primary_disk_size> Set the disk space for this VM. in GB.

=item C<swap_disk_size> Set swap space. There is no swap disk for Windows-based VMs.

=item C<required_ip_address_assignment> Set 1 if you wish the system to assign an IP automatically

=item C<required_virtual_machine_build> Set 1 to build VM automatically

=item C<template_id> The ID of a template from which a VM should be built

=back

Optional fields:

=over 4

=item C<primary_network_id> => The ID of the primary network. Optional parameter.

=item C<required_automatic_backup> Set 1 if you need automatic backups.

=item C<rate_limit> Set max port speed. Optional parameter: if none set, the system sets port speed to unlimited.

=item C<admin_note> Enter a brief comment for the VM. Optional parameter.

=item C<note> A brief comment a user can add to a VM.

=item C<hypervisor_group_id> The ID of the hypervisor zone in which the VM will be created. Optional: if no hypervisor zone is set, the VM will  be built in any available hypervisor zone.

=item C<hypervisor_id> The ID of a hypervisor where the VM will be built.

=item C<initial_root_password> Root password. [\w\-\_]{6,32} created if not supplied

=back

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
	my @requiredParams = qw/cpus memory cpu_shares hostname label primary_disk_size swap_disk_size required_ip_address_assignment required_virtual_machine_build template_id/;
	foreach my $param (@requiredParams){
		Carp::croak "Paramater '$param' not passed to createVM " unless(exists($params{$param}));
	}

	my $url = $self->_getUrl("set", "vms");
#	my $response = $self->_postJson(\%params, $url, "virtual_machine");
	my $response = $self->_postJson(
		ref => \%params,
		url => $url,
		container => "virtual_machine",
	);

	if ($response->{status_code} =~ /^2/){
		my $vmInfo = $response->{'content'};
		my $ref = $self->_makeRef($vmInfo);
		my $ref = $ref->{'virtual_machine'};
		return $ref;
	}else{
		return $response;
	}

}

sub getVMInfo{
	my $self = shift;
	my %args = @_;
	my $id = shift;
	my $url = $self->_getUrl("get", "vm");
	$url.=":".$id.".json";
#	my $response = $self->_postJson(
#		json => '',
#		url => $url,
#	);
	my $response = $self->{_userAgent}->get($url);
	if ($response->{status_code} =~ /^2/){
		my $vmInfo = $response->{'content'};
#		my $ref = $self->_makeRef($vmInfo);
#		my $ref = $ref->{'virtual_machine'};
		return $vmInfo;
	}else{
		return $response;
	}
}

=head3 chownVM

=cut

sub chownVM{
	my $self = shift;
	my %args =@_;
	my $url = $self->_getUrl("get", "vm");
	print $url;
	my @requiredParams = qw/user_id virtual_machine_id/;
	foreach(@requiredParams){
		 Carp::croak("$_ required but not supplied") unless (exists($args{$_}));
	}

#	$url.="/:".$args{'virtual_machine_id'};
	my $json = "{'user_id':'".$args{user_id}."'}";

	my $response = $self->_postJson(\%args, $url, "user");
	my $response = $self->_postJson(
		json => $json,
		url  => $url,
	);


	if ($response->{status_code} =~ /^2/){
		my $vmInfo = $response->{'content'};
		my $ref = $self->_makeRef($vmInfo);
		my $ref = $ref->{'user'};
		return $ref;
	}else{
		return $response;
	}
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

=head3 _tidyData()

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

#	if( exists($args{'andFilter'}) || exists($args{'orFilter'}) ){
#		$return = $self->_applyFilter(
#			data      => $return,
#			andFilter => $args{'andFilter'},
#		);
#	}
#	return $return;

=head3 _applyFilter(), _applyAndFilter(), _applyOrFilter()

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

=head3 _getRef()

Given a full URL (as returned by C<_getURL> ), returns a hashref containing
The data.

=cut

sub _getRef{
	my $self = shift;
	my $url = shift;
	my $response = $self->{_userAgent}->get($url);
	my $body = $response->content;
#	my $hash = decode_json($body);
	my $ref = $self->_makeRef($body);
	return $ref;
}

=head3 makeRef{
Given a JSON string, returns a reference to a hashref of it.

}

=cut

sub _makeRef{
	my $self = shift;
	my $json = shift;
	my $ref = decode_json($json);
	return $ref;
}


=head3 _postJson()

 $self->_postJson(
        url => $url,
        container => "container name",
        json => $json,
        ref => $ref
 );


Passes the ref to C<_makeJson> to turn it into JSON and then posts
that to the URL, having contained it in a single-element array by 
the name supplied to C<container>.

If C<json> is passed, this is used instead of C<_makeJson>.

On success (defined as the HTTP response code beginning with a '2') 
it returns the HTTP content of the response, which is probably JSON.

On failure, returns a hash of hopefully-useful-for-debugging data:

=over 4

=item C<json>  The JSON in the content of the request

=item C<requested_url>  The URL requested

=item C<status_code>  The numerical HTTP status 

=item C<status> The wordy HTTP status

=item C<status_description>  OnApp's description of the HTTP response code

=item C<content>  The content of the HTTP response

=item C<response_object>  The C<HTTP::Response> object returned by C<LWP::UserAgent>

=back

=cut

sub _postJson{
	my $self = shift;

	my %args = @_;
	my $json = $args{json};
	my $url = $args{url};
	my $containerName = $args{container};

	unless( exists( $args{json} ) ){
		unless ($json =~/^$/){
			$json = $self->_makeJson( $args{ref} );
			$json = '{"'.$containerName.'":'.$json.'}';
		}
	}
	my $req = HTTP::Request->new(POST => $url);
	$req->content_type('application/json');
	$req->content($json);
	my $response = $self->{_userAgent}->request($req);

	my $return = {
		json 		=> $json,
		requested_url 	=> $url,
		status_code 	=> $response->code,
		status 		=> $response->message,
		status_description => $self->_explainStatusCode($response->code),
		content 	=> $response->content,
		response_object	=> $response,
	};
	return $return
}

=head3 _get()

Is passed a URL and GETs it. Returns the same things as C<_postJson> under
the same circumstances.

=cut

sub _get{
	my $self = shift;
	my $url = shift;
	
	my $response = $self->{_userAgent}->get($url);

	my $return = {
		requested_url 	=> $url,
		status_code 	=> $response->code,
		status		=> $response->message,
		status_description => $self->_explainStatusCode($response->code),
		content 	=> $response->content,
		response_object	=> $response,
	};
	return $return;

	if ($response->{status_code} =~ /^2/){
		my $vmInfo = $response->{'content'};
		my $ref = $self->_makeRef($vmInfo);
		my $ref = $ref->{'virtual_machine'};
		return $ref;
	}else{
		return $response;
	}
}

=head4 _simpleGet()

GETs the URL passed as its only argument.

On success (defined as the HTTP status code beginning with a '2'), returns a
reference defining the JSON.

On failure, returns the C<HTTP::Response> object 

=cut

sub _simpleGet{
	my $self = shift;
	my $url = shift;

	my $response = $self->_get($url);
	if ($response->{status_code} =~ /^2/){
		my $info = $response->{'content'};
		my $ref = $self->_makeRef($info);
		return $ref;
	}else{
		my $return = {
			requested_url 	=> $url,
			status_code 	=> $response->code,
			status		=> $response->message,
			status_description => $self->_explainStatusCode($response->code),
			content 	=> $response->content,
			response_object	=> $response,
		};
		return $response;
	}
}

=head3 _explainStatusCode

 $self->_explainStatusCode($HTTPStatusCode);

Given an HTTP status code, returns OnApp's explanation of why it would return it. Text is from
the FAQ of the API guide:

=over 4

=item  C<200> "The request completed successfully",

=item  C<201> "Scheduled The request has been accepted and scheduled for processing",

=item  C<403> "Forbidden The request is correct, but could not be processed.",

=item  C<404> "The requested URL is incorrect or the resource does not exist. For example, if you request to delete a user with ID {5}, but there is no such a user in the cloud, you will get a 404 error.",

=item  C<422> "The sent parameters are erroneous.",

=item  C<500> "An error occurred. Please contact support.",

=back

=cut

sub _explainStatusCode{
	my $self = shift;
	my $code = shift;
	my %explanations = (
		200 => "The request completed successfully",
		201 => "Scheduled The request has been accepted and scheduled for processing",
		403 => "Forbidden The request is correct, but could not be processed.",
		404 => "The requested URL is incorrect or the resource does not exist. For example, if you request to delete a user with ID {5}, but there is no such a user in the cloud, you will get a 404 error.",
		422 => "The sent parameters are erroneous.",
		500 => "An error occurred. Please contact support.",
	);
	return $explanations{$code};
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

=head3 _getUrl()
Used to create URLs from easy-to-remember names. For example, to get
the correct URL for the API to return a list of users, you can do

  $self->_getURL("get", "users");

These URLs are then passed to C<_getRef>.

=cut

sub _getUrl{
	my $self = shift;
	my $getOrSet = shift;
	my $what = shift;
	my %uris = (
		get => {
			users	=> '/users.json',
			user	=> '/users/',
			vms	=> '/virtual_machines.json',
			vm	=> '/virtual_machines/',
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


=head3 _getHash()

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
but take it with a good deal of common sense.

=head1 COPYRIGHT

Copyright 2011 Avi Greenbury (bigreds)

All right reserved. This program is free software; you can redistribute it and/or modify 
it under the same terms as Perl itself or, at your option, under the BSD license.

=head1 AUTHOR
  bigreds (Avi Greenbury) bigreds@cpan.org

=cut

1;
