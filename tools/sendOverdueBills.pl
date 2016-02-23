#!/usr/bin/perl

# This file is part of Koha.
#
# Copyright (C) 2016 Observis Oy
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

use strict;
use warnings;
use CGI qw(:standard);
use CGI::Carp;

use C4::Auth;
use C4::Output;
use C4::Context;
use C4::Dates qw/format_date format_date_in_iso/;
use C4::Billing::SapErp;

use Koha::DateUtils;
use DateTime;
use POSIX;
use constant ITEM_ADD_FINE => 5.00; #Add fine per item. Predefined;

use Data::Dumper;

#Variable declarations
my $input = CGI->new;
my $dbh = C4::Context->dbh;

my $i = 0; # This variable is used as rowcounter 
my $sqlrows = 0; # For storing COUNT(*) number from sql query without LIMIT clause (max page number)

my $page = $input->param('page');
my $results = $input->param('results');
my $showall = $input->param('showall'); # Boolean 1 or 0
my $send = $input->param('send');
my $msg; #Variable for messages;

if($page < 1 || $page == ""){
	$page = 1;
}

if($results < 10 || $results > 100 || $results == ""){
	$results = 10;
}

my @paramdata; #Array for storing form parameters and values
my @overduedata; #Array for storing data from database
my $resultnumber = ($page-1)*$results;

#Form handling
if($send){
	my %form;
	
	#Row numbers starts from 1!
	for(my $j=1;$j<=100;$j++){

		if(defined param('issue_id_'.$j)){

    		$form{'borrowernumber'} = param('borrowernumber_'.$j);
            $form{'issue_id'} = param('issue_id_'.$j);
            $form{'duedate'} = param('duedate_'.$j);
            $form{'surname'} = param('surname_'.$j);
            $form{'firstname'} = param('firstname_'.$j);
            $form{'dateofbirth'} = param('dateofbirth_'.$j);
            $form{'address'} = param('address_'.$j);
            $form{'zipcode'} = param('zipcode_'.$j);  
            $form{'city'} = param('city_'.$j);
            $form{'itemnum'} = param('itemnum_'.$j);
            $form{'title'} = param('title_'.$j);
			
			#If there is "," in replacementprice as decimal separator, replace it with "."
			my $replacementprice = param('replacementprice_'.$j);
			my $position = index($replacementprice, ",");
			if($position > -1){
				$replacementprice = substr($replacementprice, $position, ".");
			}
			
			#Calculate total price
			my $totalprice = $replacementprice;
			
			$form{'replacementprice'} = $totalprice;
			$form{'fine'} = param('fine_'.$j).'.00';
			$form{'billingdate'} = param('billingdate_'.$j);

            my $overdue_price = OverduePrice($form{'itemnum'});
			
			push @paramdata, {
				
				borrowernumber => $form{'borrowernumber'},
				issue_id => $form{'issue_id'},
				duedate => $form{'duedate'},
				surname => $form{'surname'},
				firstname => $form{'firstname'},
				dateofbirth => $form{'dateofbirth'},
				address => $form{'address'},
				zipcode => $form{'zipcode'},
				city => $form{'city'},
				title => $form{'title'},
				replacementprice => $form{'replacementprice'},
				fine => $form{'fine'},
				billingdate => $form{'billingdate'},
                itemnumber => $form{'itemnum'},
                plastic => ITEM_ADD_FINE.'.00',
                overdue_price => $overdue_price
	
			};
		}
	}
	
	my $sendxml;
	
	if(@paramdata > 0){
		$sendxml = send_xml(@paramdata);
	}
	
	
	# If send_xml returns 1 (on success)...
	if($sendxml == 1){
		
		foreach my $keydata (@paramdata){
		
			if($keydata->{billingdate} eq ""){
				my $strsthinsert = "INSERT INTO overduebills (issue_id,billingdate) VALUES (?,NOW())";
				my $sthinsert=$dbh->prepare($strsthinsert);
				$sthinsert->bind_param(1, $keydata->{issue_id});
				$sthinsert->execute();
			}
			else{
				my $strsthupdate = "UPDATE overduebills SET billingdate=NOW() WHERE issue_id=?";
				my $sthupdate=$dbh->prepare($strsthupdate);
				$sthupdate->bind_param(1, $keydata->{issue_id});
				$sthupdate->execute();
			}
		}
	}
	else{
			$msg = "Can't send billing data. Select overdue items and try again to send bills.";
		}
}

#Getting data from database
my $strsth = "";

if($showall == 1){
	$strsth="SELECT TRIM(borrowers.surname) as surname,
        TRIM(borrowers.firstname) as firstname,
        borrowers.address,
        borrowers.city,
        borrowers.zipcode,
        borrowers.phone,
        borrowers.email,
        borrowers.dateofbirth,
        borrowers.borrowernumber,
        borrowers.categorycode,
        borrowers.guarantorid,
        TRIM(guarantor.firstname) as gfirstname,
        TRIM(guarantor.surname) as gsurname,
        guarantor.address as gaddress,
        guarantor.city as gcity,
        guarantor.zipcode as gzipcode,
        guarantor.phone as gphone,
        guarantor.mobile as gmobile,
        guarantor.phonepro as gphonepro,
        guarantor.email as gemail,
        issues.issue_id,
        issues.date_due,
        issues.itemnumber,
        items.barcode,
        items.replacementprice,
        biblio.title,
        biblio.author,
        biblio.biblionumber,
        overduebills.billingdate,
        overduerules.fine2 
        FROM issues 
        LEFT JOIN borrowers ON issues.borrowernumber=borrowers.borrowernumber 
        LEFT JOIN borrowers as guarantor ON guarantor.borrowernumber=borrowers.guarantorid
        LEFT JOIN borrower_attributes ba ON issues.borrowernumber=ba.borrowernumber
        LEFT JOIN items ON issues.itemnumber=items.itemnumber 
        LEFT JOIN biblioitems ON biblioitems.biblioitemnumber=items.biblioitemnumber 
        LEFT JOIN biblio ON biblio.biblionumber=items.biblionumber 
        LEFT JOIN overduebills ON overduebills.issue_id=issues.issue_id 
        LEFT JOIN overduerules ON overduerules.categorycode=borrowers.categorycode  
        WHERE issues.branchcode LIKE 'MLI_%' AND ba.attribute like 'sotu%' AND  (borrowers.categorycode = 'HENKILO' OR borrowers.categorycode = 'LAPSI') AND (NOW() > DATE_ADD(issues.date_due,INTERVAL overduerules.delay2 DAY)) 
        ORDER BY issues.date_due DESC, issues.borrowernumber ASC LIMIT ?,?";
}
else{
	$strsth="SELECT TRIM(borrowers.surname) as surname,
        TRIM(borrowers.firstname) as firstname,
        borrowers.address,
        borrowers.city,
        borrowers.zipcode,
        borrowers.phone,
        borrowers.email,
        borrowers.dateofbirth,
        borrowers.borrowernumber,
        borrowers.categorycode,
        borrowers.guarantorid,
        TRIM(guarantor.firstname) as gfirstname,
        TRIM(guarantor.surname) as gsurname,
        guarantor.address as gaddress,
        guarantor.city as gcity,
        guarantor.zipcode as gzipcode,
        guarantor.phone as gphone,
        guarantor.mobile as gmobile,
        guarantor.phonepro as gphonepro,
        guarantor.email as gemail,
        issues.issue_id,
        issues.date_due,
        issues.itemnumber,
        items.barcode,
        items.replacementprice,
        biblio.title,
        biblio.author,
        biblio.biblionumber,
        overduebills.billingdate,
        overduerules.fine2 
        FROM issues 
        LEFT JOIN borrowers ON issues.borrowernumber=borrowers.borrowernumber 
        LEFT JOIN borrowers as guarantor ON guarantor.borrowernumber=borrowers.guarantorid
	LEFT JOIN borrower_attributes ba ON issues.borrowernumber=ba.borrowernumber
        LEFT JOIN items ON issues.itemnumber=items.itemnumber 
        LEFT JOIN biblioitems ON biblioitems.biblioitemnumber=items.biblioitemnumber 
        LEFT JOIN biblio ON biblio.biblionumber=items.biblionumber 
        LEFT JOIN overduebills ON overduebills.issue_id=issues.issue_id 
        LEFT JOIN overduerules ON overduerules.categorycode=borrowers.categorycode 
        WHERE issues.branchcode LIKE 'MLI_%' AND ba.attribute like 'sotu%' AND (borrowers.categorycode = 'HENKILO' OR borrowers.categorycode = 'LAPSI') AND (NOW() > DATE_ADD(issues.date_due,INTERVAL overduerules.delay2 DAY))  
        ORDER BY issues.date_due DESC, issues.borrowernumber ASC LIMIT ?,?";
}

    
my $sth=$dbh->prepare($strsth);

$sth->bind_param(1, $resultnumber);
$sth->bind_param(2, $results);

$sth->execute();

    while (my $data = $sth->fetchrow_hashref) {
    	
    	$i++;
    	
    	my $dt = dt_from_string($data->{date_due});
    	my $billingdt = "";
    	my $birthdt = "";
    	my $borrowernumber = $data->{borrowernumber};
    	
    	if($data->{billingdate} ne ""){
    	 	$billingdt = output_pref(dt_from_string($data->{billingdate}));
    	}
    	
    	if($data->{dateofbirth} ne ""){
    	 	$birthdt = output_pref(dt_from_string($data->{dateofbirth}));
    	}
    	
    	if($data->{borrowernumber} eq ""){
    	 	$borrowernumber = "0";
    	}

        push @overduedata, {
        	duedate                	=> output_pref($dt),
        	dateofbirth				=> $birthdt,
            borrowernumber         	=> $borrowernumber,
            barcode                	=> $data->{barcode},
            itemnum                	=> $data->{itemnumber},
            surname                	=> $data->{surname},
            firstname              	=> $data->{firstname},                     
            address                	=> $data->{address},                       
            city                   	=> $data->{city},                   
            zipcode                	=> $data->{zipcode}, 
            phone                  	=> $data->{phone},
            email                  	=> $data->{email},
            biblionumber           	=> $data->{biblionumber},
            title                  	=> $data->{title},
            author                 	=> $data->{author},
            replacementprice       	=> $data->{replacementprice},
            fine			       	=> $data->{fine2},
            rowcount              	=> $i,
            issue_id             	=> $data->{issue_id},
            billingdate             => $billingdt,
            gfirstname              => $data->{gfirstname},
            gsurname                => $data->{gsurname},
            guarantorid             => $data->{guarantorid},
            gphone                  => $data->{gphone},
            gemail                  => $data->{gemail},
            gmobile                 => $data->{gmobile},
            gphonepro               => $data->{gphonepro},
            gaddress                => $data->{gaddress},                       
            gcity                   => $data->{gcity},                   
            gzipcode                => $data->{gzipcode}
        };
  	}
  	
#Getting max page number
my $strsthcount = "";
if($showall){
	$strsthcount="SELECT COUNT(*) AS sqlrows
        FROM issues 
        LEFT JOIN overduerules ON overduerules.categorycode='HENKILO'  
        WHERE issues.branchcode LIKE 'MLI_%' AND (NOW() > DATE_ADD(issues.date_due,INTERVAL overduerules.delay2 DAY))";
}
else{
	$strsthcount="SELECT COUNT(*) AS sqlrows
        FROM issues 
        LEFT JOIN borrowers ON issues.borrowernumber=borrowers.borrowernumber 
        LEFT JOIN overduerules ON overduerules.categorycode=borrowers.categorycode 
        WHERE issues.branchcode LIKE 'MLI_%' AND (NOW() > DATE_ADD(issues.date_due,INTERVAL overduerules.delay2 DAY))";
}

    
my $sthcount=$dbh->prepare($strsthcount);
$sthcount->execute();
	
$sqlrows = POSIX::ceil(($sthcount->fetchrow_hashref->{sqlrows})/$results); # Max page number

#Selecting template
my ($template, $loggedinuser, $cookie) 
= get_template_and_user({template_name => "tools/sendOverdueBills.tt",
                         type => "intranet",
                         query => $input,
                         authnotrequired => 0,
        				 flagsrequired   => { tools => 'edit_notices' },
        				 debug           => 1,
    }
);

if(@overduedata <= 0){
	$msg = "There are no overdue items to show for billing. 
	<ol>
	<li>Make sure that there is a value defined for Delay and Fine for library branches beginning with 'MLI_' at least for 'Henkilö' in second tab of 
	<a href='/cgi-bin/koha/tools/overduerules.pl'>Overdue notice/status triggers</a> page.</li>
	<li>Wait for redirection or refresh this page.</li>
	</ol>";
}

#Passing variables to template as parameters                        
$template->param(
overdueloop => \@overduedata,
rowcount => $i,
page => $page,
sqlrows => $sqlrows,
results => $results,
showall => $showall,
msg => $msg
);
                           
output_html_with_http_headers($input, $cookie, $template->output);
