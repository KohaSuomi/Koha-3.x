package C4::Form::MessagingPreferences;

# Copyright 2008-2009 LibLime
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

use strict;
use warnings;

use CGI;
use C4::Context;
use C4::Members::Messaging;
use C4::Debug;

use constant MAX_DAYS_IN_ADVANCE => 30;

=head1 NAME

C4::Form::MessagingPreferences - manage messaging preferences form

=head1 SYNOPSIS

In script:

    use C4::Form::MessagingPreferences;
    C4::Form::MessagingPreferences::set_form_value({ borrowernumber => 51 }, $template);
    C4::Form::MessagingPreferences::handle_form_action($input, { categorycode => 'CPL' }, $template);

In HTML template:

    <!-- TMPL_INCLUDE NAME="messaging-preference-form.inc" -->

=head1 DESCRIPTION

This module manages input and output for the messaging preferences form
that is used in the staff patron editor, the staff patron category editor,
and the OPAC patron messaging prefereneces form.  It in its current form,
it essentially serves only to eliminate copy-and-paste code, but suggests
at least one approach for reconciling functionality that does mostly
the same thing in staff and OPAC.

=head1 FUNCTIONS

=head2 handle_form_action

    C4::Form::MessagingPreferences::handle_form_action($input, { categorycode => 'CPL' }, $template, $insert);

Processes CGI parameters and updates the target patron or patron category's
preferences.

C<$input> is the CGI query object.

C<$target_params> is a hashref containing either a C<categorycode> key or a C<borrowernumber> key 
identifying the patron or patron category whose messaging preferences are to be updated.

C<$template> is the Template::Toolkit object for the response; this routine
adds a settings_updated template variable.

=cut

sub handle_form_action {
    my ($query, $target_params, $template, $insert, $categorycode) = @_;
    my $messaging_options = C4::Members::Messaging::GetMessagingOptions();
    # TODO: If a "NONE" box and another are checked somehow (javascript failed), we should pay attention to the "NONE" box
    my $prefs_set = 0;
    OPTION: foreach my $option ( @$messaging_options ) {
        my $updater = { borrowernumber          => $target_params->{'borrowernumber'},
                         message_attribute_id    => $option->{'message_attribute_id'} };

        my @transport_methods = $query->param($option->{'message_attribute_id'});
        # Messaging preference validation. Make sure there is a valid contact information
        # provided for every transport method. Otherwise remove the transport method,
        # because the message cannot be delivered with this method!
        if ((defined $query->param('email') && !$query->param('email') ||
            !defined $query->param('email') && !$target_params->{'email'} && exists $target_params->{'email'})
            && (my $transport_id = (List::MoreUtils::firstidx { $_ eq "email" } @transport_methods)) >-1) {

            splice(@transport_methods, $transport_id, 1);# splice the email transport method for this message
        }
        if ((defined $query->param('phone') && !$query->param('phone') ||
            !defined $query->param('phone') && !$target_params->{'phone'} && exists $target_params->{'phone'})
            && (my $transport_id = (List::MoreUtils::firstidx { $_ eq "phone" } @transport_methods)) >-1) {

            splice(@transport_methods, $transport_id, 1);# splice the phone transport method for this message
        }
        if ((defined $query->param('SMSnumber') && !$query->param('SMSnumber') ||
            !defined $query->param('SMSnumber') && !$target_params->{'smsalertnumber'} && exists $target_params->{'smsalertnumber'})
            && (my $transport_id = (List::MoreUtils::firstidx { $_ eq "sms" } @transport_methods)) >-1) {

            splice(@transport_methods, $transport_id, 1);# splice the sms transport method for this message
        }

        if (@transport_methods > 0) {
            $query->param($option->{'message_attribute_id'}, @transport_methods);
        } else {
            $query->delete($option->{'message_attribute_id'});
        }

        # find the desired transports
        @{$updater->{'message_transport_types'}} = $query->param( $option->{'message_attribute_id'} );
        next OPTION unless $updater->{'message_transport_types'};

        if ( $option->{'has_digest'} ) {
            if ( List::Util::first { $_ == $option->{'message_attribute_id'} } $query->param( 'digest' ) ) {
                $updater->{'wants_digest'} = 1;
            }
        }

        if ( $option->{'takes_days'} ) {
            if ( defined $query->param( $option->{'message_attribute_id'} . '-DAYS' ) ) {
                $updater->{'days_in_advance'} = $query->param( $option->{'message_attribute_id'} . '-DAYS' );
            }
        }

        C4::Members::Messaging::SetMessagingPreference( $updater );

	if ($query->param( $option->{'message_attribute_id'})){
	    $prefs_set = 1;
	}
    }
    if (! $prefs_set && $insert){
        # this is new borrower, and we have no preferences set, use the defaults
	$target_params->{categorycode} = $categorycode;
        C4::Members::Messaging::SetMessagingPreferencesFromDefaults( $target_params );
    }
    # show the success message
    $template->param( settings_updated => 1 ) if (defined $template);
}

=head2 set_form_values

    C4::Form::MessagingPreferences::set_form_value({ borrowernumber => 51 }, $template);

Retrieves the messaging preferences for the specified patron or patron category
and fills the corresponding template variables.

C<$target_params> is a hashref containing either a C<categorycode> key or a C<borrowernumber> key 
identifying the patron or patron category.

C<$template> is the Template::Toolkit object for the response.

=cut

sub set_form_values {
    my ($target_params, $template) = @_;
    # walk through the options and update them with these borrower_preferences
    my $messaging_options = C4::Members::Messaging::GetMessagingOptions();
    PREF: foreach my $option ( @$messaging_options ) {
        my $pref = C4::Members::Messaging::GetMessagingPreferences( { %{ $target_params }, message_name => $option->{'message_name'} } );
        $option->{ $option->{'message_name'} } = 1;
        # make a hashref of the days, selecting one.
        if ( $option->{'takes_days'} ) {
            my $days_in_advance = $pref->{'days_in_advance'} ? $pref->{'days_in_advance'} : 0;
            $option->{days_in_advance} = $days_in_advance;
            @{$option->{'select_days'}} = map { {
                day        => $_,
                selected   => $_ == $days_in_advance  }
            } ( 0..MAX_DAYS_IN_ADVANCE );
        }
        foreach my $transport ( keys %{$pref->{'transports'}} ) {
            $option->{'transports_'.$transport} = 1;
        }
        $option->{'digest'} = 1 if $pref->{'wants_digest'};
    }
    $template->param(messaging_preferences => $messaging_options);
}

=head1 TODO

=over 4

=item Reduce coupling between processing CGI parameters and updating the messaging preferences

=item Handle when form input is invalid

=item Generalize into a system of form handler clases

=back

=head1 SEE ALSO

L<C4::Members::Messaging>, F<admin/categorie.pl>, F<opac/opac-messaging.pl>, F<members/messaging.pl>

=head1 AUTHOR

Koha Development Team <http://koha-community.org/>

Galen Charlton <galen.charlton@liblime.com> refactoring code by Andrew Moore.

=cut

1;
