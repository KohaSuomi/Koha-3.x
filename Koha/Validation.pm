package Koha::Validation;

# Copyright 2015 Vaara-kirjastot
# Copyright 2016 Koha-Suomi Oy
#
# This file is part of Koha.

use utf8;
use Modern::Perl;
use Scalar::Util qw(blessed);

use Email::Valid;
use DateTime;

use C4::Context;
use C4::Biblio;

use Koha::Exception::BadParameter;
use Koha::Exception::SubroutineCall;

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

    my $regex = get_phonenumber_regex();
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
    my $validatePhoneNumber = C4::Context->preference("ValidatePhoneNumber");
    if ($validatePhoneNumber eq "ipn") {
        return qr/^((\+)?[1-9]{1,2})?([-\s\.])?((\(\d{1,4}\))|\d{1,4})(([-\s\.])?[0-9]{1,12}){1,2}$/;
    }
    elsif ($validatePhoneNumber eq "fin") {
        return qr/^((90[0-9]{3})?0|\+358([-\s])?)(?!(100|20(0|2(0|[2-3])|9[8-9])|300|600|700|708|75(00[0-3]|(1|2)\d{2}|30[0-2]|32[0-2]|75[0-2]|98[0-2])))(4|50|10[1-9]|20(1|2(1|[4-9])|[3-9])|29|30[1-9]|71|73|75(00[3-9]|30[3-9]|32[3-9]|53[3-9]|83[3-9])|2|3|5|6|8|9|1[3-9])([-\s])?(\d{1,3}[-\s]?){2,12}\d$/;
    }

    return qr/(.*)/;
}

my ($f, $sf);
sub getMARCSubfieldSelectorCache {
    return $sf;
}
sub getMARCFieldSelectorCache {
    return $f;
}
sub getMARCSelectorCache {
    return {f => $f, sf => $sf};
}


=head2 use_validator

DEPRECATED, use tries()

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

=HEAD2 tries

Same as use_validator except wraps exceptions as Exceptions
See tests in t/Koha/Validation.t for usage examples.

    my $ok = Koha::Validation->tries('key', ['koha@example.com', 'this@example.com'], 'email', 'a');
    try {
        Koha::Validation->tries('key', 'kohaexamplecom', 'email');
    } catch {
        print $_->message;
    };

@PARAM1 String, human readable key for the value we are validating
@PARAM2 Variable, variable to be validated. Can be an array or hash or a scalar
@PARAM3 String, validator selector, eg. email, phone, marcSubfieldSelector, ...
@PARAM4 String, the expected nested data types.
                For example 'aa' is a Array of arrays
                'h' is a hash
                'ah' is a array of hashes
@RETURNS 1 if everything validated ok
@THROWS Koha::Exception::BadParameter typically. See individual validator functions for Exception type specifics

=cut

sub tries {
    my ($package, $key, $val, $validator, $types) = @_;
    Koha::Exception::SubroutineCall->throw(error => _errmsg('','','You must use the object notation \'->\' instead of \'::\' to invoke me!')) unless __PACKAGE__ eq $package;

    if ($types) {
        my $t = 'v_'.substr($types,0,1); #Get first char
        $package->$t($key, $val, $validator, substr($types,1)); #Trim first char from types
    }
    else {
        $validator = 'v_'.$validator;
        my $err = __PACKAGE__->$validator($val);
        Koha::Exception::BadParameter->throw(error => _errmsg($key, $val, $err)) if $err;
        return 1;
    }
    return 1;
}

sub v_a {
    my ($package, $key, $val, $validator, $types) = @_;
    Koha::Exception::BadParameter->throw(error => _errmsg($key, $val, 'is not an \'ARRAY\'')) unless (ref($val) eq 'ARRAY');

    if ($types) {
        for (my $i=0 ; $i<@$val ; $i++) {
            my $v = $val->[$i];
            my $t = 'v_'.substr($types,0,1); #Get first char
            $package->$t($key.'->'.$i, $v, $validator, substr($types,1)); #Trim first char from types
        }
    }
    else {
        for (my $i=0 ; $i<@$val ; $i++) {
            my $v = $val->[$i];
            $package->tries($key.'->'.$i, $v, $validator, $types);
        }
    }
}
sub v_h {
    my ($package, $key, $val, $validator, $types) = @_;
    Koha::Exception::BadParameter->throw(error => _errmsg($key, $val, 'is not a \'HASH\'')) unless (ref($val) eq 'HASH');

    if ($types) {
        while(my ($k, $v) = each(%$val)) {
            my $t = 'v_'.substr($types,0,1); #Get first char
            $package->$t($key.'->'.$k, $v, $validator, substr($types,1)); #Trim first char from types
        }
    }
    else {
        while(my ($k, $v) = each(%$val)) {
            $package->tries($key.'->'.$k, $v, $validator, $types);
        }
    }
}
sub v_email {
    my ($package, $val) = @_;

    return 'is not a valid \'email\'' if (not defined Email::Valid->address($val));
    return undef;
}
sub v_DateTime {
    my ($package, $val) = @_;

    return 'is undef' unless($val);
    return 'is not blessed' unless(blessed($val));
    return 'is not a valid \'DateTime\'' unless ($val->isa('DateTime'));
    return undef;
}
sub v_digit {
    my ($package, $val) = @_;

    return 'is not a valid \'digit\'' unless ($val =~ /^-?\d+$/);
    return 'negative numbers are not a \'digit\'' if $val < 0;
    return undef;
}
sub v_double {
    my ($package, $val) = @_;

    return 'is not a valid \'double\'' unless ($val =~ /^\d+\.?\d*$/);
    return undef;
}
sub v_string {
    my ($package, $val) = @_;

    return 'is not a valid \'string\', but undefined' unless(defined($val));
    return 'is not a valid \'string\', but zero length' if(length($val) == 0);
    return 'is not a valid \'string\', but a char' if(length($val) == 1);
    return undef;
}
sub v_phone {
    my ($package, $val) = @_;

    my $regex = get_phonenumber_regex(C4::Context->preference("ValidatePhoneNumber"));
    return 'is not a valid \'phonenumber\'' if ($val !~ /$regex/);
    return undef;
}

=head2 marcSubfieldSelector

See marcSelector()

=cut

sub v_marcSubfieldSelector {
    my ($package, $val) = @_;

    if ($val =~ /^([0-9.]{3})(\w)$/) {
        ($f, $sf) = ($1, $2);
        return undef;
    }
    ($f, $sf) = (undef, undef);
    return 'is not a MARC subfield selector';
}

=head2 marcFieldSelector

See marcSelector()

=cut

sub v_marcFieldSelector {
    my ($package, $val) = @_;

    if ($val =~ /^([0-9.]{3})$/) {
        ($f, $sf) = ($1, undef);
        return undef;
    }
    ($f, $sf) = (undef, undef);
    return 'is not a MARC field selector';
}

=head2 marcSelector

Sets package variables
$__PACKAGE__::f    = MARC field code
$__PACKAGE__::sf   = MARC subfield code
if a correct MARC selector was found
for ease of access
The existing variables are overwritten when a new validation check is done.

Access them using getMARCSubfieldSelectorCache() and getMARCFieldSelectorCache()

marcSelector can also deal with any value in KohaToMARCMapping.
marcSubfieldSelector() and marcFieldSelector() deal with MARC-tags only

@PARAM1, String, current package
@PARAM2, String, MARC selector, eg. 856u or 110

=cut

sub v_marcSelector {
    my ($package, $val) = @_;

    if ($val =~ /^([0-9.]{3})(\w*)$/) {
        ($f, $sf) = ($1, $2);
        return undef;
    }
    ($f, $sf) = C4::Biblio::GetMarcFromKohaField($val, '');
    return 'is not a MARC selector' unless ($f && $sf);
    return undef;
}

sub _errmsg {
    my ($key, $val, $err) = @_;

    #Find the first call from outside this package
    my @cc; my $i = 0;
    do {
        @cc = caller($i++);
    } while ($cc[0] eq __PACKAGE__);

    return $cc[3]."() '$key' => '$val' $err\n    at ".$cc[0].':'.$cc[2];
}

1;
