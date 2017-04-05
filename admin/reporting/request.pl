#!/usr/bin/perl

use Modern::Perl;

use CGI;
use C4::Context;
use C4::Auth;
use C4::Branch;
use C4::Output;
use C4::Dates;
use C4::Form::MessagingPreferences;
use C4::Members;
use JSON;
use Data::Dumper;
use Koha::Reporting::Report::Factory;
use Koha::Reporting::Report::Renderer::Csv;

my $query = new CGI;

my $requestJson = $query->param('request_json');
my $message;

if($requestJson){
    my $reportRequest = decode_json($requestJson);
    if($reportRequest && defined $reportRequest->{name}){
        my $rows;
        my $headerRows;
        my @dataRows;
        my $renderer = new Koha::Reporting::Report::Renderer::Csv;
        my $reportFactory = new Koha::Reporting::Report::Factory();
        my $report = $reportFactory->getReportByName($reportRequest->{name});

        if($report){
           $report->setRenderer($renderer);
           $report->initFromRequest($reportRequest);
           @dataRows = $report->load();
#die Dumper @dataRows;
           if(@dataRows){
               $renderer->addColumn($report->getFactTable()->getDataColumn());
               ($headerRows, $rows) = $renderer->generateRows(\@dataRows, $report->getFactTable()->getDataColumn());

               if(@$rows){
                   if(defined $reportRequest->{selectedReportType} && $reportRequest->{selectedReportType} eq 'html'){
                       my ( $template, $borrowernumber, $cookie ) = get_template_and_user({
                           template_name   => "admin/reporting/report_html.tmpl",
                           query           => $query,
                           type            => "intranet",
                           authnotrequired => 1,
                           debug           => 1,
                       });
                       $template->param('header_rows' => $headerRows);
                       $template->param('rows' => $rows);
                       output_html_with_http_headers $query, $cookie, $template->output, undef, { force_no_caching => 1 };
                   }
                   else{
                       my $fileName = $report->getReportFileName();
                       #print "Content-Type:application/x-download\n";
                       #print "Content-Disposition:attachment;filename=$fileName\n\n";

                       print $query->header(
                          # -type => 'application/octet-stream',
                            -type => 'application/download',
                            -'Content-Transfer-Encoding' => 'binary',
                            -attachment=>"$fileName",
                            -Pragma        => 'no-cache',
                            -Cache_Control => join(', ', qw(
                                no-store
                                no-cache
                            must-revalidate
                            post-check=0
                            pre-check=0
                       )),
                       );
                       print $renderer->generateCsv($headerRows, $rows);
                   }
               }
               else{
                   die Dumper "no rows";
               }
           }
           else{
               my ( $template, $borrowernumber, $cookie ) = get_template_and_user({
                   template_name   => "admin/reporting/report_no_data.tmpl",
                   query           => $query,
                   type            => "intranet",
                   authnotrequired => 1,
                   debug           => 1,
               });
               output_html_with_http_headers $query, $cookie, $template->output, undef, { force_no_caching => 1 };
           }
        }
        
    }
}

#$message = Dumper $message;
#die($message);

