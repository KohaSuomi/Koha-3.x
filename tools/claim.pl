#!/usr/bin/perl

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# Koha; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA  02111-1307 USA

#####Sets holiday periods for each branch. Datedues will be extended if branch is closed -TG
use Modern::Perl;
use utf8;

use CGI;

use C4::Auth;
use C4::Output;
use C4::Branch;

use Data::Dumper;

use C4::OPLIB::Claiming;

my $input = new CGI;
#die Data::Dumper::Dumper($input);
my $dbh = C4::Context->dbh();
# Get the template to use
my ($template, $loggedinuser, $cookie)
    = get_template_and_user({template_name => "tools/claim.tmpl",
                             type => "intranet",
                             query => $input,
                             authnotrequired => 0,
                             flagsrequired => {tools => 'claim'},
                             debug => 0,
                           });

my $operation = 'main_view'; #Sets the default operation
$operation = 'close_letters' if $input->param('close_letters'); #Mark the claimletters as 'sent' to the message_queue-table and fine our Patrons.
$operation = 'get_letters' if $input->param('get_letters'); #Simply get the letters for browsing
my $removeStaleLetters = 0;
$removeStaleLetters = '1' if $input->param('remove_stale_letters'); #Remove all not-closed claimletters.
my $outputFormat = $input->param('outputFormat') eq 'asTxt' ? '.txt' : '.odt';


####------------------####
##!# Get claimletters #!##
####------------------####
if ($operation eq 'get_letters' || $operation eq 'close_letters') {

    C4::OPLIB::Claiming::removeStaleOdts() if $removeStaleLetters;

    my $args = {};
    my @branches = $input->param('branches');
    $args->{claimbranches} = \@branches;
    $args->{closeclaim} = 1 if $operation eq 'close_letters';
    my $generatedFiles = C4::OPLIB::Claiming::processODUECLAIM( $args );

    if ($generatedFiles && scalar(@$generatedFiles) > 1) {
        #We have more than one generated file, so we cannot upload all of them. So redirect to "static_content/claiming/"
        if ($operation eq 'close_letters') {
            print $input->redirect('/static_content/claiming/old_claims/') ;
        }
        elsif ($operation eq 'get_letters') {
            print $input->redirect('/static_content/claiming/') ;
        }
    }
    elsif ($generatedFiles && scalar(@$generatedFiles) == 1) {
        #We have but one generated file, we can easily send it to the user!
        if ($generatedFiles->[0] =~ /\/([^\/]+)$/) {
            my $filename = $1.$outputFormat;
            open(my $fh, "<", $generatedFiles->[0].$outputFormat) or die "Couldn't open the claimletter file $filename for sending! ".$!;
            binmode $fh;


            print "Content-Type:application/x-download\n";
            print "Content-Disposition:attachment;filename=$filename\n";
            print "\n"; #Extra fuuken newline to prevent malformed header error.
            print <$fh>;

            close $fh;
        }
    }
    else {
        #There was nothing to claim in that branch!
        $template->param( nothing_to_claim_branch => "@branches" );
        #Display the default view
        $operation = 'main_view';
    }
}


####----------------####
##!# Show main view #!##
####----------------####
if ($operation eq 'main_view') {

    my $branchloop = C4::Branch::GetBranchesLoop();

    my $branchcounts = C4::OPLIB::Claiming::getClaimletterCountByBranch();
    foreach my $branch (@$branchloop) {
        if ( exists $branchcounts->{  $branch->{branchcode}  } ) {
            $branch->{claimscount} = $branchcounts->{  $branch->{branchcode}  };
        }

    }

    $template->param(
        branchloop               => $branchloop,
#        HOLIDAYS_LOOP            => \@holidays,
#        EXCEPTION_HOLIDAYS_LOOP  => \@exception_holidays,
#        DAY_MONTH_HOLIDAYS_LOOP  => \@day_month_holidays,
#        calendardate             => $calendardate,
#        keydate                  => $keydate,
#        branchcodes              => $branchcodes,
#        branch                   => $branch,
#        branchname               => $branchname,
#        branch                   => $branch,
    );
    # Shows the template with the real values replaced
    C4::Output::output_html_with_http_headers($input, $cookie, $template->output);
}

exit 0;