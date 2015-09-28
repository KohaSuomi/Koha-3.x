#!/usr/bin/perl

# Copyright 2011-2013 Biblibre SARL
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

=head1 NAME

showpredictionpattern.pl

=head1 DESCRIPTION

This script calculate numbering of serials based on numbering pattern, and
publication date, based on frequency and first publication date.

=cut

use Modern::Perl;

use CGI;
use Date::Calc qw(Today Day_of_Year Week_of_Year Day_of_Week Days_in_Year Delta_Days Add_Delta_Days Add_Delta_YM);
use C4::Auth;
use C4::Output;
use C4::Serials;
use C4::Serials::Frequency;

my $input = new CGI;
my ($template, $loggedinuser, $cookie, $flags) = get_template_and_user( {
    template_name   => 'serials/showpredictionpattern.tt',
    query           => $input,
    type            => 'intranet',
    authnotrequired => 0,
    flagsrequired   => { 'serials' => '*' },
} );

my $subscriptionid = $input->param('subscriptionid');
my $frequencyid = $input->param('frequency');
my $firstacquidate = $input->param('firstacquidate');
my $nextacquidate = $input->param('nextacquidate');
my $enddate = $input->param('enddate');
my $subtype = $input->param('subtype');
my $sublength = $input->param('sublength');
my $custompattern = $input->param('custompattern');

my $frequency = GetSubscriptionFrequency($frequencyid);

my %pattern = (
    numberingmethod => $input->param('numberingmethod') // '',
    numbering1      => $input->param('numbering1') // '',
    numbering2      => $input->param('numbering2') // '',
    numbering3      => $input->param('numbering3') // '',
    add1            => $input->param('add1') // '',
    add2            => $input->param('add2') // '',
    add3            => $input->param('add3') // '',
    whenmorethan1   => $input->param('whenmorethan1') // '',
    whenmorethan2   => $input->param('whenmorethan2') // '',
    whenmorethan3   => $input->param('whenmorethan3') // '',
    setto1          => $input->param('setto1') // '',
    setto2          => $input->param('setto2') // '',
    setto3          => $input->param('setto3') // '',
    every1          => $input->param('every1') // '',
    every2          => $input->param('every2') // '',
    every3          => $input->param('every3') // '',
);

if(!defined $firstacquidate || $firstacquidate eq ''){
    my ($year, $month, $day) = Today();
    $firstacquidate = sprintf "%04d-%02d-%02d", $year, $month, $day;
} else {
    $firstacquidate = C4::Dates->new($firstacquidate)->output('iso');
}

if($enddate){
    $enddate = C4::Dates->new($enddate)->output('iso');
}

if($nextacquidate) {
    $nextacquidate = C4::Dates->new($nextacquidate)->output('iso');
} else {
    $nextacquidate = $firstacquidate;
}
my $date = $nextacquidate;

my %subscription = (
    locale      => $input->param('locale') // '',
    lastvalue1      => $input->param('lastvalue1') // '',
    lastvalue2      => $input->param('lastvalue2') // '',
    lastvalue3      => $input->param('lastvalue3') // '',
    innerloop1      => $input->param('innerloop1') // '',
    innerloop2      => $input->param('innerloop2') // '',
    innerloop3      => $input->param('innerloop3') // '',
    irregularity    => '',
    periodicity     => $frequencyid,
    countissuesperunit  => 1,
    firstacquidate  => $firstacquidate,
);

my $issuenumber;
if(defined $subscriptionid) {
    ($issuenumber) = C4::Serials::GetFictiveIssueNumber(\%subscription, $date);
} else {
    $issuenumber = 1;
}

my @predictions_loop;
my ($calculated) = GetSeq(\%subscription, \%pattern);
push @predictions_loop, {
    number => $calculated,
    publicationdate => $date,
    issuenumber => $issuenumber,
    dow => Day_of_Week(split /-/, $date),
};
my @irreg = ();
if(defined $subscriptionid) {
    @irreg = C4::Serials::GetSubscriptionIrregularities($subscriptionid);
    while(@irreg && $issuenumber > $irreg[0]) {
        shift @irreg;
    }
    if(@irreg && $issuenumber == $irreg[0]){
        $predictions_loop[0]->{'not_published'} = 1;
        shift @irreg;
    }
}

my $i = 1;
while( $i < 1000 ) {
    my %line;

    if(defined $date){
        $date = GetNextDate(\%subscription, $date);
    }
    if(defined $date){
        $line{'publicationdate'} = $date;
        $line{'dow'} = Day_of_Week(split /-/, $date);
    }

    # Check if we don't have exceed end date
    if($sublength){
        if($subtype eq "numberlength" && $i >= $sublength){
            last;
        } elsif($subtype eq "weeklength" && $date && Delta_Days( split(/-/, $date), Add_Delta_Days( split(/-/, $firstacquidate), 7*$sublength - 1 ) ) < 0) {
            last;
        } elsif($subtype eq "monthlength" && $date && (Delta_Days( split(/-/, $date), Add_Delta_YM( split(/-/, $firstacquidate), 0, $sublength) ) - 1) < 0 ) {
            last;
        }
    }
    if($enddate && $date && Delta_Days( split(/-/, $date), split(/-/, $enddate) ) <= 0 ) {
        last;
    }

    ($calculated, $subscription{'lastvalue1'}, $subscription{'lastvalue2'}, $subscription{'lastvalue3'}, $subscription{'innerloop1'}, $subscription{'innerloop2'}, $subscription{'innerloop3'}) = GetNextSeq(\%subscription, \%pattern);
    $issuenumber++;
    $line{'number'} = $calculated;
    $line{'issuenumber'} = $issuenumber;
    if(@irreg && $issuenumber == $irreg[0]){
        $line{'not_published'} = 1;
        shift @irreg;
    }
    push @predictions_loop, \%line;

    $i++;
}

$template->param(
    predictions_loop => \@predictions_loop,
);

if ( $frequency->{unit} and not $custompattern ) {
    $template->param( ask_for_irregularities => 1 );
    if ( $frequency->{unit} eq 'day' and $frequency->{unitsperissue} == 1 ) {
        $template->param( daily_options => 1 );
    }
}

if (   ( $date && $enddate && $date ne $enddate )
    or ( $subtype eq 'numberlength' && $i < $sublength ) )
{
    $template->param( not_consistent_end_date => 1 );
}

output_html_with_http_headers $input, $cookie, $template->output;
