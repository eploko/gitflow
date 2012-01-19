#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use MIME::Base64;

use LWP::UserAgent 6;

$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;

use JIRA::Client;

sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

my $user             = trim(`git config --get gitflow.ld.username`);
my $encoded_password = trim(`git config --get gitflow.ld.password`);
my $password         = trim(decode_base64($encoded_password));
my $jira_base_url    = 'https://jira.yandex-team.ru/';

my %workflow_statuses = {
	'Open' => 1,
	'In Progress' => 3,
	'Code Review' => 10011,
	'Resolved' => 5,
	'Closed' => 6
};

my %workflow_resolutions = {
	'Fixed' => 1,
	'Won\'t Fix' => 2,
	'Duplicate' => 3,
	'Incomplete' => 4,
	'Can\'t Reproduce' => 5,
	'Delayed' => 6,
	'Invalid' => 10
};

my $jira = JIRA::Client->new( $jira_base_url, $user, $password );

#my $issue = eval { $jira->getIssue("MOBCODEBASE-353") };
#print "Issue: " . Dumper($issue) . "\n";
#print "Resolution: " . $issue->{resolution} . "\n";
#print "Status: " . $issue->{status} . "\n";
#print Dumper($jira->get_statuses());

sub dieTicketInvalid() {
	die "Feature name is not a valid jira-ticket.\n";
}

sub dieTicketAlreadyWorking() {
	die "Feature is already in progress.\n";
}

sub dieTicketNotWorking() {
	die "Feature is not in progress.\n";
}

sub dieTicketNotFinished() {
	die "Feature is not done yet.\n";
}

# start new feature
sub startFeature {
	my $newFeature = $_[0];
	my $curFeature = trim(`git config --get gitflow.prefix.feature.issue`);

	if ( "$curFeature" ne "" ) { 
		# get the current ticket
		my $curIssue = eval { $jira->getIssue($curFeature) };
		# move issue over the workflow (stop progress)
		$jira->progress_workflow_action_safely(
			$curIssue,
			'Stop Progress'
		);
	}

	# get the new ticket
	my $newIssue = eval { $jira->getIssue($newFeature) };
	my $assignee = $newIssue->{assignee};
	# check tiket exists
	dieTicketInvalid() if $@;
	# check ticket is opened
	dieTicketAlreadyWorking() if ($newIssue->{status} != 1);
	
	# start the feature
	system("git flow feature start $newFeature");
	# remember ticket & assignee 
	system("git config gitflow.prefix.feature.issue $newFeature");
	system("git config gitflow.prefix.feature.assignee $assignee");
	
	# move issue over the workflow (start progress)
	$jira->progress_workflow_action_safely(
		$newIssue,
		'Start Progress'
	);
}

# finish current feature
sub finishFeature {
	my $feature = $_[0];
	
	# get the ticket
	my $issue = eval { $jira->getIssue($feature) };
	# check tiket exists
	dieTicketInvalid() if $@;
	# check ticket is resolved
	dieTicketNotFinished() if ($issue->{status} != 5 && $issue->{status} != 6);
	
	# clear config
	system("git config --unset gitflow.prefix.feature.issue");
	system("git config --unset gitflow.prefix.feature.assignee");
	# finish feature
	system("git flow feature finish $feature");
}

if ("$ARGV[0]" eq "start") {
	startFeature "$ARGV[1]";
} elsif ("$ARGV[0]" eq "finish") {
	finishFeature "$ARGV[1]";
}
