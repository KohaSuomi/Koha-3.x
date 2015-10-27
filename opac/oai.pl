#!/usr/bin/perl

# Copyright Biblibre 2008
# Copyright The National Library of Finland 2015
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


use strict;
use warnings;

use CGI qw( :standard -oldstyle_urls -utf8 );
use vars qw( $GZIP );
use C4::Context;


BEGIN {
    eval { require PerlIO::gzip };
    $GZIP = ($@) ? 0 : 1;
}

unless ( C4::Context->preference('OAI-PMH') ) {
    print
        header(
            -type       => 'text/plain; charset=utf-8',
            -charset    => 'utf-8',
            -status     => '404 OAI-PMH service is disabled',
        ),
        "OAI-PMH service is disabled";
    exit;
}

my @encodings = http('HTTP_ACCEPT_ENCODING');
if ( $GZIP && grep { defined($_) && $_ eq 'gzip' } @encodings ) {
    print header(
        -type               => 'text/xml; charset=utf-8',
        -charset            => 'utf-8',
        -Content-Encoding   => 'gzip',
    );
    binmode( STDOUT, ":gzip" );
}
else {
    print header(
        -type       => 'text/xml; charset=utf-8',
        -charset    => 'utf-8',
    );
}

binmode STDOUT, ':encoding(UTF-8)';
# OAI-PMH handles dates in UTC, so do that on the database level to avoid the
# need for any conversions
C4::Context->dbh->prepare("SET time_zone='+00:00'")->execute();
my $repository = C4::OAI::Repository->new();

# __END__ Main Prog


#
# Extends HTTP::OAI::ResumptionToken
# A token is identified by:
# - metadataPrefix
# - from
# - until
# - offset
#
package C4::OAI::ResumptionToken;

use strict;
use warnings;
use HTTP::OAI;

use base ("HTTP::OAI::ResumptionToken");


sub new {
    my ($class, %args) = @_;

    my $self = $class->SUPER::new(%args);

    my ($metadata_prefix, $offset, $from, $until, $set, $stage);
    if ( $args{ resumptionToken } ) {
        ($metadata_prefix, $offset, $from, $until, $set, $stage)
            = split( '/', $args{resumptionToken} );
    }
    else {
        $metadata_prefix = $args{ metadataPrefix };
        $from = $args{ from } || '1970-01-01';
        $until = $args{ until };
        unless ( $until) {
            my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) = gmtime( time );
            $until = sprintf( "%.4d-%.2d-%.2d", $year+1900, $mon+1,$mday );
        }
        $offset = $args{ offset } || 0;
        $set = $args{set};
        $stage = (defined $args{stage}) ? $args{stage} : 0;
    }

    $self->{ metadata_prefix } = $metadata_prefix;
    $self->{ offset          } = $offset;
    $self->{ from            } = $from;
    $self->{ until           } = $until;
    $self->{ set             } = $set;
    $self->{ stage           } = $stage;

    $self->resumptionToken(
        join( '/', $metadata_prefix, $offset, $from, $until, $set, $stage ) );
    $self->cursor( $offset );

    return $self;
}

# __END__ C4::OAI::ResumptionToken



package C4::OAI::Identify;

use strict;
use warnings;
use HTTP::OAI;
use C4::Context;

use base ("HTTP::OAI::Identify");

sub new {
    my ($class, $repository) = @_;

    my ($baseURL) = $repository->self_url() =~ /(.*)\?.*/;
    my $self = $class->SUPER::new(
        baseURL             => $baseURL,
        repositoryName      => C4::Context->preference("LibraryName"),
        adminEmail          => C4::Context->preference("KohaAdminEmailAddress"),
        MaxCount            => C4::Context->preference("OAI-PMH:MaxCount"),
        granularity         => 'YYYY-MM-DDThh:mm:ssZ',
        earliestDatestamp   => '0001-01-01T00:00:00Z',
        deletedRecord       => 'persistent',
    );

    # FIXME - alas, the description element is not so simple; to validate
    # against the OAI-PMH schema, it cannot contain just a string,
    # but one or more elements that validate against another XML schema.
    # For now, simply omitting it.
    # $self->description( "Koha OAI Repository" );

    $self->compression( 'gzip' );

    return $self;
}

# __END__ C4::OAI::Identify



package C4::OAI::ListMetadataFormats;

use strict;
use warnings;
use HTTP::OAI;

use base ("HTTP::OAI::ListMetadataFormats");

sub new {
    my ($class, $repository) = @_;

    my $self = $class->SUPER::new();

    if ( $repository->{ conf } ) {
        foreach my $name ( @{ $repository->{ koha_metadata_format } } ) {
            my $format = $repository->{ conf }->{ format }->{ $name };
            $self->metadataFormat( HTTP::OAI::MetadataFormat->new(
                metadataPrefix    => $format->{metadataPrefix},
                schema            => $format->{schema},
                metadataNamespace => $format->{metadataNamespace}, ) );
        }
    }
    else {
        $self->metadataFormat( HTTP::OAI::MetadataFormat->new(
            metadataPrefix    => 'oai_dc',
            schema            => 'http://www.openarchives.org/OAI/2.0/oai_dc.xsd',
            metadataNamespace => 'http://www.openarchives.org/OAI/2.0/oai_dc/'
        ) );
        $self->metadataFormat( HTTP::OAI::MetadataFormat->new(
            metadataPrefix    => 'marc21',
            schema            => 'http://www.loc.gov/MARC21/slim http://www.loc.gov/ standards/marcxml/schema/MARC21slim.xsd',
            metadataNamespace => 'http://www.loc.gov/MARC21/slim http://www.loc.gov/ standards/marcxml/schema/MARC21slim'
        ) );
        $self->metadataFormat( HTTP::OAI::MetadataFormat->new(
            metadataPrefix    => 'marcxml',
            schema            => 'http://www.loc.gov/MARC21/slim http://www.loc.gov/ standards/marcxml/schema/MARC21slim.xsd',
            metadataNamespace => 'http://www.loc.gov/MARC21/slim http://www.loc.gov/ standards/marcxml/schema/MARC21slim'
        ) );
    }

    return $self;
}

# __END__ C4::OAI::ListMetadataFormats



package C4::OAI::Record;

use strict;
use warnings;
use HTTP::OAI;
use HTTP::OAI::Metadata::OAI_DC;

use base ("HTTP::OAI::Record");

sub new {
    my ($class, $repository, $marcxml, $timestamp, $setSpecs, $deleted, %args) = @_;

    my $self = $class->SUPER::new(%args);

    $timestamp =~ s/ /T/, $timestamp .= 'Z';
    $self->header( new HTTP::OAI::Header(
        identifier  => $args{identifier},
        datestamp   => $timestamp,
        status => $deleted ? 'deleted' : undef
    ) );

    foreach my $setSpec (@$setSpecs) {
        $self->header->setSpec($setSpec);
    }

    if (!$deleted) {
        my $parser = XML::LibXML->new();
        my $record_dom = $parser->parse_string( $marcxml );
        my $format =  $args{metadataPrefix};
        if ( $format ne 'marcxml' && $format ne 'marc21' ) {
            my %args = (
                OPACBaseURL => "'" . C4::Context->preference('OPACBaseURL') . "'"
            );
            $record_dom = $repository->stylesheet($format)->transform($record_dom, %args);
        }
        $self->metadata( HTTP::OAI::Metadata->new( dom => $record_dom ) );
    }

    return $self;
}

# __END__ C4::OAI::Record



package C4::OAI::GetRecord;

use strict;
use warnings;
use HTTP::OAI;
use C4::OAI::Sets;

use base ("HTTP::OAI::GetRecord");


sub new {
    my ($class, $repository, %args) = @_;

    my $self = HTTP::OAI::GetRecord->new(%args);

    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("
        SELECT marcxml, timestamp
        FROM   biblioitems
        WHERE  biblionumber=? " );
    my $prefix = $repository->{koha_identifier} . ':';
    my ($biblionumber) = $args{identifier} =~ /^$prefix(.*)/;
    $sth->execute( $biblionumber );
    my ($marcxml, $timestamp);
    unless ( ($marcxml, $timestamp) = $sth->fetchrow ) {
        return HTTP::OAI::Response->new(
            requestURL  => $repository->self_url(),
            errors      => [ new HTTP::OAI::Error(
                code    => 'idDoesNotExist',
                message => "There is no biblio record with this identifier",
                ) ] ,
        );
    }

    my $oai_sets = GetOAISetsBiblio($biblionumber);
    my @setSpecs;
    foreach (@$oai_sets) {
        push @setSpecs, $_->{spec};
    }

    #$self->header( HTTP::OAI::Header->new( identifier  => $args{identifier} ) );
    $self->record( C4::OAI::Record->new(
        $repository, $marcxml, $timestamp, \@setSpecs, %args ) );

    return $self;
}

# __END__ C4::OAI::GetRecord



package C4::OAI::ListIdentifiers;

use strict;
use warnings;
use HTTP::OAI;
use C4::OAI::Sets;

use base ("HTTP::OAI::ListIdentifiers");


sub new {
    my ($class, $repository, %args) = @_;

    my $self = HTTP::OAI::ListIdentifiers->new(%args);

    my $token = new C4::OAI::ResumptionToken( %args );
    my $dbh = C4::Context->dbh;
    my $set;
    if(defined $token->{'set'}) {
        $set = GetOAISetBySpec($token->{'set'});
    }
    my $max = $repository->{'koha_max_count'};
    my $offset = $token->{'offset'};

    my $count = 0;
    # Since creating a union of normal and deleted record tables would be a heavy
    # operation, build results in two stages: first deleted records, then normal records
    MAINLOOP:
    for ( my $stage = $token->{'stage'}; $stage < 2; $stage++ ) {
        my $sql = C4::OAI::Utils->build_list_sql($stage == 0, $set, $max, $offset);
        my $sth = $dbh->prepare( $sql ) || die('Query preparation failed: ' . $dbh->errstr);
        my @bind_params = (C4::OAI::Utils->fix_date($token->{'from'}, 0), C4::OAI::Utils->fix_date($token->{'until'}, 1));
        push @bind_params, $set->{'id'} if defined $set;
        $sth->execute( @bind_params ) || die('Query failed: ' . $dbh->errstr);

        while ( my ($biblionumber, $timestamp) = $sth->fetchrow ) {
            $count++;
            if ( $count > $max ) {
                $self->resumptionToken(
                    new C4::OAI::ResumptionToken(
                        metadataPrefix  => $token->{metadata_prefix},
                        from            => $token->{from},
                        until           => $token->{until},
                        offset          => $offset + $max,
                        set             => $token->{set},
                        stage           => $stage
                    )
                );
                last MAINLOOP;
            }
            $timestamp =~ s/ /T/, $timestamp .= 'Z';
            my $header = new HTTP::OAI::Header(
                identifier => $repository->{ koha_identifier} . ':' . $biblionumber,
                datestamp  => $timestamp,
            );
            if ($stage == 0) {
                $header->status( 'deleted' );
            }
            $self->identifier( $header );
        }
        # Reset offset for next stage
        $offset = 0;
    }

    return $self;
}

# __END__ C4::OAI::ListIdentifiers

package C4::OAI::Description;

use strict;
use warnings;
use HTTP::OAI;
use HTTP::OAI::SAXHandler qw/ :SAX /;

sub new {
    my ( $class, %args ) = @_;

    my $self = {};

    if(my $setDescription = $args{setDescription}) {
        $self->{setDescription} = $setDescription;
    }
    if(my $handler = $args{handler}) {
        $self->{handler} = $handler;
    }

    bless $self, $class;
    return $self;
}

sub set_handler {
    my ( $self, $handler ) = @_;

    $self->{handler} = $handler if $handler;

    return $self;
}

sub generate {
    my ( $self ) = @_;

    g_data_element($self->{handler}, 'http://www.openarchives.org/OAI/2.0/', 'setDescription', {}, $self->{setDescription});

    return $self;
}

# __END__ C4::OAI::Description

package C4::OAI::ListSets;

use strict;
use warnings;
use HTTP::OAI;
use C4::OAI::Sets;

use base ("HTTP::OAI::ListSets");

sub new {
    my ( $class, $repository, %args ) = @_;

    my $self = HTTP::OAI::ListSets->new(%args);

    my $token = C4::OAI::ResumptionToken->new(%args);
    my $sets = GetOAISets;
    my $pos = 0;
    foreach my $set (@$sets) {
        if ($pos < $token->{offset}) {
            $pos++;
            next;
        }
        my @descriptions;
        foreach my $desc (@{$set->{'descriptions'}}) {
            push @descriptions, C4::OAI::Description->new(
                setDescription => $desc,
            );
        }
        $self->set(
            HTTP::OAI::Set->new(
                setSpec => $set->{'spec'},
                setName => $set->{'name'},
                setDescription => \@descriptions,
            )
        );
        $pos++;
        last if ($pos + 1 - $token->{offset}) > $repository->{koha_max_count};
    }

    $self->resumptionToken(
        new C4::OAI::ResumptionToken(
            metadataPrefix => $token->{metadata_prefix},
            offset         => $pos
        )
    ) if ( $pos > $token->{offset} );

    return $self;
}

# __END__ C4::OAI::ListSets;

package C4::OAI::ListRecords;

use strict;
use warnings;
use HTTP::OAI;
use C4::OAI::Sets;

use base ("HTTP::OAI::ListRecords");


sub new {
    my ($class, $repository, %args) = @_;

    my $self = HTTP::OAI::ListRecords->new(%args);

    my $token = new C4::OAI::ResumptionToken( %args );
    my $dbh = C4::Context->dbh;
    my $set;
    if(defined $token->{'set'}) {
        $set = GetOAISetBySpec($token->{'set'});
    }
    my $offset = $token->{'offset'};
    my $max = $repository->{'koha_max_count'};
    my $query = '
SELECT biblioitems.marcxml
FROM biblioitems
WHERE biblionumber = ?
';
    my $marc_sth = $dbh->prepare($query) || die('Query preparation failed: ' . $dbh->errstr);

    my $count = 0;
    # Since creating a union of normal and deleted record tables would be a heavy
    # operation, build results in two stages: first deleted records, then normal records
    MAINLOOP:
    for ( my $stage = $token->{'stage'}; $stage < 2; $stage++ ) {
        my $sql = C4::OAI::Utils->build_list_sql($stage == 0, $set, $max, $offset);
        my $sth = $dbh->prepare( $sql ) || die('Query preparation failed: ' . $dbh->errstr);
        my @bind_params = (C4::OAI::Utils->fix_date($token->{'from'}, 0), C4::OAI::Utils->fix_date($token->{'until'}, 1));
        push @bind_params, $set->{'id'} if defined $set;
        $sth->execute( @bind_params ) || die('Query failed: ' . $dbh->errstr);

        while ( my ($biblionumber, $timestamp) = $sth->fetchrow ) {
            $count++;
            if ( $count > $max ) {
                $self->resumptionToken(
                    new C4::OAI::ResumptionToken(
                        metadataPrefix  => $token->{metadata_prefix},
                        from            => $token->{from},
                        until           => $token->{until},
                        offset          => $offset + $max,
                        set             => $token->{set},
                        stage           => $stage
                    )
                );
                last MAINLOOP;
            }
            my $marcxml = '';
            if ($stage == 1) {
                $marc_sth->execute(($biblionumber)) || die('Query failed: ' . $dbh->errstr);
                my @marc_results = $marc_sth->fetchrow_array();
                if (@marc_results) {
                    $marcxml = $marc_results[0];
                }
            }
            my $oai_sets = GetOAISetsBiblio($biblionumber);
            my @setSpecs;
            foreach (@$oai_sets) {
                push @setSpecs, $_->{spec};
            }
            $self->record( C4::OAI::Record->new(
                $repository, $marcxml, $timestamp, \@setSpecs, $stage == 0 || !$marcxml,
                identifier      => $repository->{ koha_identifier } . ':' . $biblionumber,
                metadataPrefix  => $token->{metadata_prefix}
            ) );
        }
        # Reset offset for next stage
        $offset = 0;
    }

    return $self;
}

# __END__ C4::OAI::ListRecords

package C4::OAI::Utils;

use strict;

sub fix_date {
    my ($class, $date, $end) = @_;

    if (length($date) == 10) {
        if ($end) {
            $date .= ' 23:59:59';
        } else {
            $date .= ' 00:00:00';
        }
    } else {
        $date = substr($date, 0, 10) . ' ' . substr($date, 11, 8);
    }
    return $date;
}

sub build_list_sql {
    my ($class, $deleted, $set, $max, $offset) = @_;

    my $table = $deleted ? 'deletedbiblioitems' : 'biblioitems';

    my $sql = "
SELECT bi.biblionumber, bi.timestamp
  FROM $table bi
  WHERE bi.timestamp >= ? AND bi.timestamp <= ?
  ORDER BY bi.biblionumber
";

    # Use a subquery for sets since it allows us to use an index for the subquery in
    # biblioitems table and is quite a bit faster than a join.
    if (defined $set) {
        $sql = "
SELECT bi.* FROM ($sql) bi
  WHERE bi.biblionumber in (SELECT osb.biblionumber FROM oai_sets_biblios osb WHERE osb.set_id = ?)
";
    }
    $sql .= '
  LIMIT ' . ($max + 1) . "
  OFFSET $offset
";

    return $sql;
}

# __END__ C4::OAI::Utils;



package C4::OAI::Repository;

use base ("HTTP::OAI::Repository");

use strict;
use warnings;

use HTTP::OAI;
use HTTP::OAI::Repository qw/:validate/;

use XML::SAX::Writer;
use XML::LibXML;
use XML::LibXSLT;
use YAML::Syck qw( LoadFile );
use CGI qw/:standard -oldstyle_urls/;

use C4::Context;
use C4::Biblio;


sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(%args);

    $self->{ koha_identifier      } = C4::Context->preference("OAI-PMH:archiveID");
    $self->{ koha_max_count       } = C4::Context->preference("OAI-PMH:MaxCount");
    $self->{ koha_metadata_format } = ['oai_dc', 'marc21', 'marcxml'];
    $self->{ koha_stylesheet      } = { }; # Build when needed

    # Load configuration file if defined in OAI-PMH:ConfFile syspref
    if ( my $file = C4::Context->preference("OAI-PMH:ConfFile") ) {
        $self->{ conf } = LoadFile( $file );
        my @formats = keys %{ $self->{conf}->{format} };
        $self->{ koha_metadata_format } =  \@formats;
    }

    # Check for grammatical errors in the request
    my @errs = validate_request( CGI::Vars() );

    # Is metadataPrefix supported by the respository?
    my $mdp = param('metadataPrefix') || '';
    if ( $mdp && !grep { $_ eq $mdp } @{$self->{ koha_metadata_format }} ) {
        push @errs, new HTTP::OAI::Error(
            code    => 'cannotDisseminateFormat',
            message => "Dissemination as '$mdp' is not supported",
        );
    }

    my $response;
    if ( @errs ) {
        $response = HTTP::OAI::Response->new(
            requestURL  => self_url(),
            errors      => \@errs,
        );
    }
    else {
        my %attr = CGI::Vars();
        my $verb = delete( $attr{verb} );
        if ( $verb eq 'ListSets' ) {
            $response = C4::OAI::ListSets->new($self, %attr);
        }
        elsif ( $verb eq 'Identify' ) {
            $response = C4::OAI::Identify->new( $self );
        }
        elsif ( $verb eq 'ListMetadataFormats' ) {
            $response = C4::OAI::ListMetadataFormats->new( $self );
        }
        elsif ( $verb eq 'GetRecord' ) {
            $response = C4::OAI::GetRecord->new( $self, %attr );
        }
        elsif ( $verb eq 'ListRecords' ) {
            $response = C4::OAI::ListRecords->new( $self, %attr );
        }
        elsif ( $verb eq 'ListIdentifiers' ) {
            $response = C4::OAI::ListIdentifiers->new( $self, %attr );
        }
    }

    $response->set_handler( XML::SAX::Writer->new( Output => *STDOUT ) );
    $response->generate;

    bless $self, $class;
    return $self;
}


sub stylesheet {
    my ( $self, $format ) = @_;

    my $stylesheet = $self->{ koha_stylesheet }->{ $format };
    unless ( $stylesheet ) {
        my $xsl_file = $self->{ conf }
                       ? $self->{ conf }->{ format }->{ $format }->{ xsl_file }
                       : ( C4::Context->config('intrahtdocs') .
                         '/prog/en/xslt/' .
                         C4::Context->preference('marcflavour') .
                         'slim2OAIDC.xsl' );
        my $parser = XML::LibXML->new();
        my $xslt = XML::LibXSLT->new();
        my $style_doc = $parser->parse_file( $xsl_file );
        $stylesheet = $xslt->parse_stylesheet( $style_doc );
        $self->{ koha_stylesheet }->{ $format } = $stylesheet;
    }

    return $stylesheet;
}



=head1 NAME

C4::OAI::Repository - Handles OAI-PMH requests for a Koha database.

=head1 SYNOPSIS

  use C4::OAI::Repository;

  my $repository = C4::OAI::Repository->new();

=head1 DESCRIPTION

This object extend HTTP::OAI::Repository object.
It accepts OAI-PMH HTTP requests and returns result.

This OAI-PMH server can operate in a simple mode and extended one.

In simple mode, repository configuration comes entirely from Koha system
preferences (OAI-PMH:archiveID and OAI-PMH:MaxCount) and the server returns
records in marcxml or dublin core format. Dublin core records are created from
koha marcxml records tranformed with XSLT. Used XSL file is located in
koha-tmpl/intranet-tmpl/prog/en/xslt directory and choosed based on marcflavour,
respecively MARC21slim2OAIDC.xsl for MARC21 and  MARC21slim2OAIDC.xsl for
UNIMARC.

In extende mode, it's possible to parameter other format than marcxml or Dublin
Core. A new syspref OAI-PMH:ConfFile specify a YAML configuration file which
list available metadata formats and XSL file used to create them from marcxml
records. If this syspref isn't set, Koha OAI server works in simple mode. A
configuration file koha-oai.conf can look like that:

  ---
  format:
    vs:
      metadataPrefix: vs
      metadataNamespace: http://veryspecial.tamil.fr/vs/format-pivot/1.1/vs
      schema: http://veryspecial.tamil.fr/vs/format-pivot/1.1/vs.xsd
      xsl_file: /usr/local/koha/xslt/vs.xsl
    marc21 or marcxml:
      metadataPrefix: marc21 or marxml
      metadataNamespace: http://www.loc.gov/MARC21/slim http://www.loc.gov/standards/marcxml/schema/MARC21slim
      schema: http://www.loc.gov/MARC21/slim http://www.loc.gov/standards/marcxml/schema/MARC21slim.xsd
    oai_dc:
      metadataPrefix: oai_dc
      metadataNamespace: http://www.openarchives.org/OAI/2.0/oai_dc/
      schema: http://www.openarchives.org/OAI/2.0/oai_dc.xsd
      xsl_file: /usr/local/koha/koha-tmpl/intranet-tmpl/xslt/UNIMARCslim2OAIDC.xsl

=cut



