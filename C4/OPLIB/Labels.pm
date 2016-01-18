package C4::OPLIB::Labels;

## USING PURE SQL HERE BECAUSE DON'T WANT TO CAUSE git CONFLICT POSSIBILITIES IN DBIx OBJECT DEFINITIONS. + DBIx SUCKS DONKEY BALLS. ##
use Modern::Perl;
use Carp; $Carp::Verbose=1;

use C4::Context;

sub getMappings {
    my $dbh = C4::Context->dbh();
    
    my $sth = $dbh->prepare('SELECT olm.*, it.description AS itype_desc,
                                    br.branchname AS branchcode_name,
                                    loc.lib AS location_lib, loc.authorised_value AS location_value,
                                    ccod.lib AS ccode_lib, ccod.authorised_value AS ccode_value
                            FROM oplib_label_mappings olm
                            LEFT JOIN authorised_values loc ON loc.id = olm.location
                            LEFT JOIN authorised_values ccod ON ccod.id = olm.ccode
                            LEFT JOIN itemtypes it ON it.itemtype = olm.itype
                            LEFT JOIN branches br ON br.branchcode = olm.branchcode
                            ORDER BY olm.branchcode, loc.authorised_value, olm.itype, ccod.authorised_value');
    $sth->execute( );
    
    if ( $sth->err ) {
        return $sth->err;
    }
    
    return $sth->fetchall_arrayref({});
}

sub upsertMapping {
    my $olm = shift;
    _set_NULL_to_NULL($olm);
    
    my $dbh = C4::Context->dbh();
    my $sth;
    
    if ($olm->{id}) {
        $sth = $dbh->prepare('UPDATE oplib_label_mappings SET
                              timestamp=?, modifiernumber=?,
                              description=?, branchcode=?, location=?,
                              itype=?, ccode=?, label=?
                              WHERE id=?');
        $sth->execute( $olm->{timestamp},  $olm->{modifiernumber},
                       $olm->{description}, $olm->{branchcode}, $olm->{location},
                       $olm->{itype},       $olm->{ccode},      $olm->{label},
                       #WHERE id =
                       $olm->{id} );
    }
    else {
        $sth = $dbh->prepare('INSERT INTO oplib_label_mappings VALUES (?,?,?,?,?,?,?,?,?)');
        $sth->execute( $olm->{id},          $olm->{timestamp},  $olm->{modifiernumber},
                       $olm->{label},       $olm->{branchcode}, $olm->{location},
                       $olm->{itype},       $olm->{ccode},      $olm->{description} );
    }
    if ( $sth->err ) {
        return $sth->err;
    }
    return undef;
}

sub deleteMapping {
    my $olm = shift;
    
    my $dbh = C4::Context->dbh();
    my $sth;
    
    if ($olm->{id}) {
        $sth = $dbh->prepare('DELETE FROM oplib_label_mappings WHERE id = ?');
        $sth->execute( $olm->{id} );
    }
    else {
        croak "oplib-label-mapping -object doesn't contain the id-column!";
    }
    if ( $sth->err ) {
        return $sth->err;
    }
    return undef;
}

#The templates cannot give an undefind value so we need to manually undef them
sub _set_NULL_to_NULL {
    my $olm = shift;
    foreach my $key (keys %$olm) {
        delete $olm->{$key} if $olm->{$key} eq '';
    }
}
sub _set_NULL_to__ {
    my $olm = shift;
    foreach my $key (keys %$olm) {
        $olm->{$key} = '' if exists $olm->{$key} && not(defined($olm->{$key}));
    }
}

sub getShelvingLabelsMap {
    my $olms = shift;
    $olms = getMappings() unless $olms;

    _set_NULL_to__($_) foreach @$olms;

    my $map = {};
    foreach my $m (@$olms) {
        #Store to the map the code values, not the integer id's because this is a common referencing behaviour in Koha.
        $map->{ $m->{branchcode} }->{ $m->{location_value} }->{ $m->{itype} }->{ $m->{ccode_value} } = $m->{label};
    }

    return $map;
}
sub getReverseShelvingLabelsMap {
    my $olms = shift;
    $olms = getMappings() unless $olms;

    _set_NULL_to__($_) foreach @$olms;

    my $map = {};
    foreach my $m (@$olms) {
        #Store to the map the code values, not the integer id's because this is a common referencing behaviour in Koha.
        $map->{ $m->{label} } = $m;
    }

    return $map;
}

sub getLabelFromMap {
    my ($map, $branchcode, $location, $itype, $ccode) = @_;

    my $branchlevel = $map->{$branchcode};
    $branchlevel = $map->{''} unless $branchlevel;
    my $locationlevel = $branchlevel->{$location};
    $locationlevel = $branchlevel->{''} unless $locationlevel;
    my $itypelevel = $locationlevel->{$itype};
    $itypelevel = $locationlevel->{''} unless $itypelevel;
    my $ccodelevel = $itypelevel->{$ccode};
    $ccodelevel = $itypelevel->{''} unless $ccodelevel;
    
    return $ccodelevel;
}

sub getLabel {
    my ($branchcode, $location, $itype, $ccode) = @_;

    my $dbh = C4::Context->dbh();

    my $sth = $dbh->prepare('SELECT olm.label
                            FROM oplib_label_mappings olm
                            LEFT JOIN authorised_values loc ON loc.id = olm.location
                            LEFT JOIN authorised_values ccod ON ccod.id = olm.ccode
                            WHERE (olm.branchcode = ? OR olm.branchcode IS NULL) AND
                                  (loc.authorised_value = ? OR loc.authorised_value IS NULL) AND
                                  (olm.itype = ? OR olm.itype IS NULL) AND
                                  (ccod.authorised_value = ? OR ccod.authorised_value IS NULL)
                            ORDER BY olm.branchcode, loc.authorised_value, olm.itype, ccod.authorised_value
                            LIMIT 1');
    $sth->execute( $branchcode, $location, $itype, $ccode );

    if ( $sth->err ) {
        my @cc = caller(0);
        Koha::Exception::DB->throw(error => $cc[3]."(@_):> ".$sth->errstr);
    }

    my $row = $sth->fetchrow_hashref();
    return ($row->{label}) ? $row->{label} : undef;
}

sub getAuthorised_value {
    my ($authorised_value, $id) = @_;
    
    my $dbh = C4::Context->dbh();
    my @params;
    my @wheres;
    my $sql = 'SELECT * FROM authorised_values WHERE ';
    push @wheres, "authorised_value = ?" if $authorised_value;
    push @params, $authorised_value if $authorised_value;
    push @wheres, "id = ?" if $id;
    push @params, $id if $id;
    
    $sql .= join(' AND ', @wheres);
    
    my $sth = $dbh->prepare($sql);
    $sth->execute(@params);
    
    if ( $sth->err ) {
        return $sth->err;
    }
    return $sth->fetchrow_hashref();
}

=head importLabels

    our $legacy_labels = {
        'JOE_VII' => {
                      'VVA' => 'LIEVIVALI', 'AIK' => 'LIVA', 'HEN' => 'LIVH', 'NUA' => 'LIVNA',
                      'NUO' => 'LIVN', 'KUV' => 'LIVL', 'REF' => 'LIVK'
                     },
        'JOE_RAN' => {
                      'AIK' => 'RAA', 'LAP' => 'RAN', 'Rantakylän kirjasto' => 'RA', 'NUA' => 'RANA', 'REF' => 'RAK'
                     },
        'JOE_POL' => {
                      'LAP' => 'PON', 'HEN' => 'POEH', 'AIK' => 'POA', 'KAD' => 'POEKAD', 'OHE' => 'POEOL',
                      'VAR' => 'POVA', 'KOT' => 'POKO', 'LVA' => 'POVN', 'Polvijärven kirjasto' => 'PO', 'ILM' => 'POEIP', 'REF' => 'POK'
                     },
    };
    C4::OPLIB::Labels::importLabels( $legacy_labels );

Imports labels from a given hash, where 1st level keys are branchcodes and 2nd level keys are shelving location codes.
Constructs $olm (oplib_label_mapping) -objects out of the hash and upserts them using upsertMapping();

=cut

sub importLabels {
    my $legacy_tables = shift;

    foreach my $branchcode (keys $legacy_tables) {
        my $branch = $legacy_tables->{ $branchcode };
        foreach my $location (keys $branch) {
            next if length $location > 10;
            
            my $label = $branch->{ $location };
            my $location_id = C4::OPLIB::Labels::getAuthorised_value( $location )->{id};
            
            
            my $olm = {};
            $olm->{branchcode} = $branchcode;
            $olm->{location}   = $location_id;
            $olm->{label}      = $label;
            $olm->{modifiernumber} = 3;
            C4::OPLIB::Labels::upsertMapping( $olm );
        }
    }
}

return 1;
