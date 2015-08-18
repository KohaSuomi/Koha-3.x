package Koha::Validation;

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

use utf8;
use strict;
use warnings;

use C4::Context;
use Email::Valid;

use vars qw($VERSION);

=head1 NAME

Koha::Validation - validates inputs

=head1 SYNOPSIS

  use Koha::Validation

=head1 DESCRIPTION

This module lets you validate given inputs.

=head2 validate_email

Validates given email.

  Koha::Validation::validate_email("email@address.com");

returns: 1 if the given email is valid, 0 otherwise.

=cut

sub validate_email {

    my $address = shift;

    # make sure we are allowed to validate emails
    return 1 if not C4::Context->preference("ValidateEmailAddress");
    return 1 if not $address;
    return 0 if $address =~ /(^(\s))|((\s)$)/;
    $address =~ s/[Ää]/a/g;
    $address =~ s/[Öö]/o/g;
    $address =~ s/[Åå]/o/g;

    return (not defined Email::Valid->address($address)) ? 0:1;
}

=head2 validate_phonenumber

Validates given phone number.

  Koha::Validation::validate_phonenumber(123456789);

returns: 1 if the given phone number is valid, 0 otherwise.

=cut

sub validate_phonenumber {
    my $phonenumber = shift;

    # make sure we are allowed to validate phone numbers
    return 1 if C4::Context->preference("ValidatePhoneNumber") eq "OFF";
    return 1 if not $phonenumber;
    return 0 if $phonenumber =~ /(^(\s))|((\s)$)/;

    my $regex = get_phonenumber_regex(C4::Context->preference("ValidatePhoneNumber"));
    return ($phonenumber !~ /$regex/) ? 0:1;
}

=head2 get_phonenumber_regex

Returns the used regex (according to ValidatePhoneNumber system preference) for phone numbers.
This is used to share the same regex between Perl scripts and JavaScript in templates.

  Koha::Validation::get_phonenumber_regex();

International phone numbers (ipn): http://regexlib.com/REDetails.aspx?regexp_id=3009

returns: the regex

=cut

sub get_phonenumber_regex {
    if (C4::Context->preference("ValidatePhoneNumber") eq "ipn") {
        return qr/^((\+)?[1-9]{1,2})?([-\s\.])?((\(\d{1,4}\))|\d{1,4})(([-\s\.])?[0-9]{1,12}){1,2}$/;
    }
    elsif (C4::Context->preference("ValidatePhoneNumber") eq "fin") {
        return qr/^((90[0-9]{3})?0|\+358([-\s])?)(?!(100|20(0|2(0|[2-3])|9[8-9])|300|600|700|708|75(00[0-3]|(1|2)\d{2}|30[0-2]|32[0-2]|75[0-2]|98[0-2])))(4|50|10[1-9]|20(1|2(1|[4-9])|[3-9])|29|30[1-9]|71|73|75(00[3-9]|30[3-9]|32[3-9]|53[3-9]|83[3-9])|2|3|5|6|8|9|1[3-9])([-\s])?(\d{1,3}[-\s]?){2,12}\d$/;
    }

    return qr/(.*)/;
  }


=head2 use_validator

Validates given input with given validator.

  Koha::Validation::use_validator("phone", 123456789);
  Koha::Validation::use_validator("email", "email@address.com");

Currently supported validators are
  email, e-mail
  phone, phonenumber

returns: 1 if the given input is valid with the given validator, 0 otherwise.

=cut

sub use_validator {
    my ($validator, $input) = @_;

    if (not defined $validator or not defined $input) {
        warn "Subroutine must be called with validator and input";
        return 0;
    }

    return validate_email($input) if $validator eq "email" or $validator eq "e-mail";
    return validate_phonenumber($input) if $validator eq "phone" or $validator eq "phonenumber";

    warn "Validator not found";
    return 0;
}

1;
