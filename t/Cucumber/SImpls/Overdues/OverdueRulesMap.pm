package SImpls::Overdues::OverdueRulesMap;

# Copyright 2015 Vaara-kirjastot
#
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
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;
use Carp;

use Test::More;

use Koha::Overdues::OverdueRule;
use Koha::Overdues::OverdueRulesMap;

sub _splitMessageTransportTypes {
    my $messageTransportTypesString = shift; #Get a comma separated string.

    my %otts = map {my $a = $_; $a =~ s/\s//g; $a => 1;} split(',',$messageTransportTypesString) if $messageTransportTypesString; #Make a HASH out of the comma-separated list of types and remove whitespace.
    return \%otts;
}

=head _hashifyDataArray

Concatenate the first 3 columns, branchCode, borrowerCategory, letterNumber as the hash key.
This is needed to make this data element compatible with the Object Factories.

=cut

sub _hashifyDataArray {
    my $data = shift;

    if (ref $data eq 'ARRAY') {
        my $dataHash = {};
        foreach my $dataElem (@$data) {
            my $key = join('','DEL_'.$dataElem->{branchCode}.$dataElem->{borrowerCategory}.$dataElem->{letterNumber});
            $dataHash->{ $key } = $dataElem;
        }
        return $dataHash;
    }
    elsif (ref $data eq 'HASH') {
        return $data;
    }
}

sub addOverdueRules {
    my $C = shift;
    my $S = $C->{stash}->{scenario};
    my $F = $C->{stash}->{feature};

    my $orm = Koha::Overdues::OverdueRulesMap->new();
    $S->{overdueRules} = {} unless $S->{overdueRules};
    $F->{overdueRules} = {} unless $F->{overdueRules};
    for (my $i=0 ; $i<scalar(@{$C->data()}) ; $i++) {
        my $overdueruleHash = $C->data()->[$i];

        #Hashify the given message transpor types String
        my %otts = map {my $a = $_; $a =~ s/\s//g; $a => 1;} split(',',$overdueruleHash->{messageTransportTypes}) if $overdueruleHash->{messageTransportTypes}; #Make a HASH out of the comma-separated list of types and remove whitespace.
        $overdueruleHash->{messageTransportTypes} = \%otts;

        my ($overdueRule, $error) = $orm->upsertOverdueRule($overdueruleHash);
        is($error, undef, "Adding an OverdueRule succeeded.");

        my $key = $overdueRule->{branchCode}.$overdueRule->{borrowerCategory}.$overdueRule->{letterNumber};
        $S->{overdueRules}->{$key} = $overdueRule;
        $F->{overdueRules}->{$key} = $overdueRule;
    }
    $orm->store();
}

sub deleteAllOverdueRules {
    my $C = shift;
    my $F = $C->{stash}->{feature};

    my $orm = Koha::Overdues::OverdueRulesMap->new();
    $orm->deleteAllOverdueRules();
}

sub When_I_try_to_add_overduerules_with_bad_values_I_get_errors {
    my ($C) = shift;
    my $data = $C->data();

    my $orm = Koha::Overdues::OverdueRulesMap->new();

    foreach my $dataElem (@$data) {
        $dataElem->{messageTransportTypes} = _splitMessageTransportTypes(  $dataElem->{messageTransportTypes}  );

        my ($overdueRule, $error) = $orm->upsertOverdueRule($dataElem);

        is($error, $dataElem->{errorCode}, "Adding a bad overdueRule failed.");
    }
}

sub When_I_ve_deleted_overduerules_then_cannot_find_them {
    my ($C) = shift;
    my $S = $C->{stash}->{scenario};
    $S->{overdueRules} = _hashifyDataArray( $C->data() );

    my $orm = Koha::Overdues::OverdueRulesMap->new();

    while( my ($key, $dataElem) = each %{$S->{overdueRules}}) {
        $dataElem->{messageTransportTypes} = _splitMessageTransportTypes(  $dataElem->{messageTransportTypes}  );

        my $oldOverdueRule = $orm->getOverdueRule( $dataElem->{branchCode}, $dataElem->{borrowerCategory}, $dataElem->{letterNumber} );
        isa_ok($oldOverdueRule, 'Koha::Overdues::OverdueRule');

        my $error = $orm->deleteOverdueRule($oldOverdueRule);

        $orm->store();

        #Test from $orm internal memory structure
        my $newOverdueRule = $orm->getOverdueRule( $dataElem->{branchCode}, $dataElem->{borrowerCategory}, $dataElem->{letterNumber} );
        is($newOverdueRule, undef, 'OverdueRule succesfully deleted from internal memory');

        #Refresh the $orm from DB
        $orm = Koha::Overdues::OverdueRulesMap->new();
        $newOverdueRule = $orm->getOverdueRule( $dataElem->{branchCode}, $dataElem->{borrowerCategory}, $dataElem->{letterNumber} );

        is($newOverdueRule, undef, 'OverdueRule succesfully deleted from the DB');
    }
}

sub getLastOverdueRules {
    my ($C, $context) = @_;
    my $S = $C->{stash}->{scenario};

    my $orm = Koha::Overdues::OverdueRulesMap->new();
    my $overduerule = $orm->getLastOverdueRules();
    $S->{lastOverdueRules} = $overduerule;
}

sub Find_the_overduerules_from_overdueRulesMap {
    my ($C) = shift;
    my $S = $C->{stash}->{scenario};

    my $orm = Koha::Overdues::OverdueRulesMap->new();

    my ($newOverdueRule, $oldOverdueRule, $error);
    while( my ($key, $dataElem) = each %{$S->{overdueRules}}) {
        ($newOverdueRule, $error) = Koha::Overdues::OverdueRule->new($dataElem);
        $oldOverdueRule = $orm->getOverdueRule( $dataElem->{branchCode}, $dataElem->{borrowerCategory}, $dataElem->{letterNumber} );

        last unless is_deeply($oldOverdueRule, $newOverdueRule, "We got what we put");
        last unless isa_ok($newOverdueRule, 'Koha::Overdues::OverdueRule');
    }
}

=head Then_get_following_last_overduerules

Compares a $C->data() -Array of Hashes of OverdueRule-object elements
against a Scenario stash of Array of OverdueRule-objects.

=cut

sub Then_get_following_last_overduerules {
    my ($C) = shift;
    my $S = $C->{stash}->{scenario};
    my $expectedOverdueRules = _hashifyDataArray( $C->data() );
    my $gotOverdueRules = _hashifyDataArray( $S->{lastOverdueRules} );

    ##Iterate through the expected OverdueRules Hash containing Hash-representations of expected OverdueRules.
    while( my ($eKey, $eorHash) = each %{$expectedOverdueRules}) {
        my $matchFound; #Check if we found a match for this expectation?

        #Cast the expected Hash to a proper OverdueRule-object for comparison.
        #Hashify the given message transpor types String
        my %otts = map {my $a = $_; $a =~ s/\s//g; $a => 1;} split(',',$eorHash->{messageTransportTypes}) if $eorHash->{messageTransportTypes}; #Make a HASH out of the comma-separated list of types and remove whitespace.
        $eorHash->{messageTransportTypes} = \%otts;
        my ($eor, $error) = Koha::Overdues::OverdueRule->new($eorHash);

        #Iterate each result we got from getLastOverdueRules(), and if the keys match, deeply compare them.
        while( my ($gKey, $gor) = each %{$gotOverdueRules}) {
            unless ($eKey eq $gKey) {
                next();
            }
            last unless is_deeply($gor, $eor, "We got what we put");
            last unless isa_ok($gor, 'Koha::Overdues::OverdueRule');
            $matchFound++;
        }
    }
}

1; #Return 'true' for happy happy joy joy!
