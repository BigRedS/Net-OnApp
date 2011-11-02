#! /usr/bin/perl

package OnApp::API;

use strict;
use 5.010;
use Carp;
use LWP::UserAgent;
use JSON;
use Data::Dumper;

my $VERSION;
$VERSION=0.20111102;

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

sub getHash(){
	my $self = shift;
	my $url = shift;
	my $response = $self->{_userAgent}->get($url);
	my $json = $response->content;
	my $data = from_json($json);
	return $data;

}

sub getUsers(){
	my $self = shift;
	my $url = $self->{_url}."/users.json";
	my $data = $self->getHash($url);
	print Dumper($data);
}




1;

