#!/usr/bin/perl

#script to administer the branches table
#written 20/02/2002 by paul.poulain@free.fr
# This software is placed under the gnu General Public License, v2 (http://www.gnu.org/licenses/gpl.html)

# ALGO :
# this script use ano $op to know what to do.
# if $op is empty or none of the above values,
#	- the default screen is build (with all records, or filtered datas).
#	- the   user can clic on add, modify or delete record.
# if $op=add_form
#	- if primkey exists, this is a modification,so we read the $primkey record
#	- builds the add/modify form
# if $op=add_validate
#	- the user has just send datas, so we create/modify the record
# if $op=delete_form
#	- we show the record having primkey=$primkey and ask for deletion validation form
# if $op=delete_confirm
#	- we delete the record having primkey=$primkey

use strict;
use warnings;
use CGI;
use C4::Context;
use C4::Auth;
use C4::Output;
use C4::Breeding;

sub StringSearch  {
	my ($searchstring,$type)=@_;
	my $dbh = C4::Context->dbh;
    my @data = ('%');
    my $count = 1;
	if ( defined $searchstring ) {
        $searchstring =~ s/\'/\\\'/g;
        @data=split(' ',$searchstring);
        $count=@data;
    }
    else {
        $searchstring = '';
    }

    my $query    = "SELECT host,port,db,userid,password,name,id,checked,rank,syntax,encoding,timeout,recordtype";
    $query      .= " FROM z3950servers";
    if ( $searchstring ne '' ) { $query .= " WHERE (name like ?)" }
    $query      .= " ORDER BY rank,name";
	my $sth=$dbh->prepare($query);

    if ( $searchstring ne '' ) {
        $sth->execute("$data[0]\%");
    }
    else {
        $sth->execute;
    }

    my @results;
    while (my $data=$sth->fetchrow_hashref) {
        push(@results,$data);
    }
    $sth->finish;
    return (scalar(@results),\@results);
}

my $input = new CGI;
my $searchfield=$input->param('searchfield');
my $offset=$input->param('offset') || 0;
my $script_name="/cgi-bin/koha/admin/z3950servers.pl";

my $pagesize=20;
my $op = $input->param('op') || '';

my ($template, $loggedinuser, $cookie) 
    = get_template_and_user({template_name => "admin/z3950servers.tmpl",
				query => $input,
				type => "intranet",
				authnotrequired => 0,
                flagsrequired => {parameters => 'parameters_remaining_permissions'},
				debug => 1,
				});


$template->param(script_name => $script_name,
                 searchfield => $searchfield);


################## ADD_FORM ##################################
# called by default. Used to create form to add or  modify a record
if ( $op eq 'add_form' ) {
    $template->param( add_form => 1 );

    #---- if primkey exists, it's a modify action, so read values to modify...
    my $data;
    if (defined($searchfield)) {
        $data = C4::Breeding::getZ3950server({name => $searchfield});
    }
    $template->param( $_ => $data->{$_} )
      for (qw( host port db userid password checked rank timeout encoding ));
    $template->param( $_ . $data->{$_} => 1 ) for (qw( syntax recordtype ));

    # END $OP eq ADD_FORM
################## ADD_VALIDATE ##################################
    # called by add_form, used to insert/modify data in DB
} elsif ($op eq 'add_validate') {
    my $params = castCGIToZ3950serverParams($input);
    my $dbh=C4::Context->dbh;
    my ($sth, $sql, $server);

    $server = C4::Breeding::getZ3950server(  $params->{id} ? {id => $params->{id}} : {name => $params->{name}}  );
    if ($server) {
        C4::Breeding::updateZ3950server($params);
        $template->param(confirm_update => 1);
    }
    else {
        C4::Breeding::addZ3950server($params);
        $template->param(confirm_add => 1);
    }
    # END $OP eq ADD_VALIDATE
################## DELETE_CONFIRM ##################################
# called by default form, used to confirm deletion of data in DB
} elsif ($op eq 'delete_confirm') {
    $template->param( delete_confirm => 1 );
    my $data = C4::Breeding::getZ3950server({name => $searchfield});

    $template->param(
        host       => $data->{'host'},
        port       => $data->{'port'},
        db         => $data->{'db'},
        userid     => $data->{'userid'},
        password   => $data->{'password'},
        checked    => $data->{'checked'},
        rank       => $data->{'rank'},
        syntax     => $data->{'syntax'},
        timeout    => $data->{'timeout'},
        recordtype => $data->{'recordtype'},
        encoding   => $data->{'encoding'}
    );

													# END $OP eq DELETE_CONFIRM
################## DELETE_CONFIRMED ##################################
# called by delete_confirm, used to effectively confirm deletion of data in DB
} elsif ($op eq 'delete_confirmed') {
	$template->param(delete_confirmed => 1);
    my $server = C4::Breeding::getZ3950server({name => $searchfield});
    C4::Breeding::deleteZ3950server($server->{id});
													# END $OP eq DELETE_CONFIRMED
################## DEFAULT ##################################
} else { # DEFAULT
	$template->param(else => 1);
	my ($count,$results)=StringSearch($searchfield,'web');
	my @loop;

	for (my $i=$offset; $i < ($offset+$pagesize<$count?$offset+$pagesize:$count); $i++){
		my $urlsearchfield=$results->[$i]{name};
		$urlsearchfield=~s/ /%20/g;
		my %row	= ( name => $results->[$i]{'name'},
			host => $results->[$i]{'host'},
			port => $results->[$i]{'port'},
			db => $results->[$i]{'db'},
			userid =>$results->[$i]{'userid'},
			password => ($results->[$i]{'password'}) ? ('#######') : ('&nbsp;'),
			checked => $results->[$i]{'checked'},
			rank => $results->[$i]{'rank'},
			syntax => $results->[$i]{'syntax'},
			encoding => $results->[$i]{'encoding'},
      timeout => $results->[$i]{'timeout'},
            recordtype => $results->[$i]{'recordtype'});
		push @loop, \%row;

	}
	$template->param(loop => \@loop);
	if ($offset>0) {
		$template->param(offsetgtzero => 1,
				prevpage => $offset-$pagesize);
	}
	if ($offset+$pagesize<$count) {
		$template->param(ltcount => 1,
				 nextpage => $offset+$pagesize);
	}
} #---- END $OP eq DEFAULT
output_html_with_http_headers $input, $cookie, $template->output;

sub castCGIToZ3950serverParams {
    my ($cgi) = @_;

    my $params = {};
    $params->{'host'} =        $input->param('host'),
    $params->{'port'} =        $input->param('port'),
    $params->{'db'} =          $input->param('db'),
    $params->{'userid'} =      $input->param('userid'),
    $params->{'password'} =    $input->param('password'),
    $params->{'name'} =        $input->param('searchfield'),
    $params->{'checked'} =     $input->param('checked') ? 1 : 0,
    $params->{'rank'} =        $input->param('rank'),
    $params->{'syntax'} =      $input->param('syntax'),
    $params->{'encoding'} =    $input->param('encoding'),
    $params->{'timeout'} =     $input->param('timeout'),
    $params->{'recordtype'} =  $input->param('recordtype'),
    $params->{'searchfield'} = $input->param('searchfield'),
    return $params;
}