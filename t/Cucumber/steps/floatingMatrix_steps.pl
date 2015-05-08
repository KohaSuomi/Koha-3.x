#!/usr/bin/perl

# Copyright Vaara-kirjastot 2015
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
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
use Test::More;
use Test::BDD::Cucumber::StepFile;

use SImpls::FloatingMatrix;

Given qr/there are no Floating matrix rules/, sub {
    SImpls::FloatingMatrix::deleteAllFloatingMatrixRules(@_);
};

Given qr/a set of Floating matrix rules/, sub {
    SImpls::FloatingMatrix::addFloatingMatrixRules(@_);
};

When qr/I've deleted the following Floating matrix rules, then I cannot find them./, sub {
    SImpls::FloatingMatrix::When_I_ve_deleted_Floating_matrix_rules_then_cannot_find_them(@_);
};

When qr/I try to add Floating matrix rules with bad values, I get errors./, sub {
    SImpls::FloatingMatrix::When_I_try_to_add_Floating_matrix_rules_with_bad_values_I_get_errors(@_);
};

When qr/I test if given Items can float, then I see if this feature works!/, sub {
    SImpls::FloatingMatrix::When_test_given_Items_floats_then_see_status(@_);
};

Then qr/I should find the rules from the Floating matrix/, sub {
    SImpls::FloatingMatrix::checkFloatingMatrixRules(@_);
};

Then qr/there are no Floating matrix rules/, sub {
    my $schema = Koha::Database->new()->schema();
    my @fmRules = $schema->resultset('FloatingMatrix')->search({})->all;
    is((scalar(@fmRules)), 0, "Cleaning Floating matrix rules succeeded");
};
