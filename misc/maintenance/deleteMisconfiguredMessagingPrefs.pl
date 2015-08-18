#!/usr/bin/perl

#-----------------------------------
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
#-----------------------------------

use strict;
use warnings;
use C4::Context;
use DBI;
use Email::Valid;
use POSIX qw(strftime);
use Getopt::Long;
use C4::Members::Messaging;

my $helptext = "
This script deletes misconfigured messaging preferences from the Koha database. A preference is
misconfigured if the user has no valid contact information for that type of transport method.
E.g user wants messages via e-mail while he has not provided an e-mail address.

Options:
    -h|--help           Prints this help documentation.
    -b|--backup:s       Filename for backup file. Required in 'restore' mode and optional in 'delete' mode.
                        Default value is messaging-prefs-backup_<date and time>. In 'delete' mode, if nothing
                        gets deleted, the file will not be created.
    -d|--delete         Activates the deletion mode (cannot be used simultaneously with mode 'restore').
    -r|--restore        Activates the restore mode (cannot be used simultaneously with mode 'delete').
    -m|--methods=s{1,3} Optional. Specifies the transfer methods/types. The three types are: email phone sms.
                        If not provided, all three types are used.

Examples:
    ./deleteMisconfiguredMessagingPrefs.pl -d -b
    ./deleteMisconfiguredMessagingPrefs.pl -d -t email phone -b
    ./deleteMisconfiguredMessagingPrefs.pl -d -t email phone sms -b my_backup_file
    ./deleteMisconfiguredMessagingPrefs.pl -r -b my_backup_file
\n";

my ($help, $delete, $filename, $restore, @methods);

GetOptions(
    'h|help' => \$help,
    'd|delete' => \$delete,
    'r|restore' => \$restore,
    'b|backup:s' => \$filename,
    'm|methods=s{1,3}' => \@methods
);

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
my $are_we_doing_backups = 0;


if ($help || $restore && $delete || !$restore && !$delete) {
    die $helptext;
}
if ($delete and $filename eq "" or length($filename) > 0) {
    $are_we_doing_backups = 1;
    $filename = (strftime "messaging-prefs-backup_%Y-%m-%d_%H-%M-%S", localtime) if ($filename eq "");
    # first, make sure we can do backups
    open(my $file, ">>", $filename) or die "Could not open file for writing.\n";
}












if ($delete) {
    my @deleted_prefs;

    # check if user has specified messaging transport methods
    if (@methods > 0 && @methods < 4) {
        my $correct_modes = 0;

        foreach my $type (@methods){

            if ($type eq "email" or $type eq "phone" or $type eq "sms") {
                print "Deleting misconfigured $type messaging preferences\n";

                # method exists, don't need to print warning anymore
                $correct_modes = 1;

                # which contact info field (primary email / primary phone / smsalertnumber)
                # should we check?
                my $contact;
                $contact = "email" if $type eq "email";
                $contact = "phone" if $type eq "phone";
                $contact = "smsalertnumber" if $type eq "sms";

                # which validator should we use?
                my $validator;
                $validator = "email" if $type eq "email";
                $validator = "phone" if $type eq "phone" or $type eq "sms";

                # delete the misconfigured prefs and keep a counting them
                push(@deleted_prefs, C4::Members::Messaging::DeleteMisconfiguredPreference($type, $contact, $validator));
            }
        }

        die "Missing or invalid in parameter --type values. See help.\n$helptext" if $correct_modes == 0;

    } else {

        # user did not specify any methods. so let's delete them all!
        print "Deleting all misconfigured messaging preferences\n";
        push(@deleted_prefs, C4::Members::Messaging::DeleteAllMisconfiguredPreferences());

    }

    BackupDeletedPrefs(@deleted_prefs) if $are_we_doing_backups;

    print "Deleted ".scalar(@deleted_prefs)." misconfigured messaging preferences in total.\n";
}
elsif ($restore){
    if (@methods > 0) {
        my $correct_modes = 0;
        for (my $i=0; $i < @methods; $i++){
            if ($methods[$i] ne "email" and $methods[$i] ne "phone" and $methods[$i] ne "sms") {
                print "Invalid type $methods[$i]. Valid types are: email phone sms\n";
                splice(@methods, $i);
            }
        }
        die "Missing parameter --type values. See help.\n$helptext" if @methods == 0;
        RestoreDeletedPreferences(@methods);
    } else {
        RestoreDeletedPreferences();
    }
}















# restoring deleted prefs

sub BackupDeletedPrefs {
    my @deleted = @_;

    open(my $fh, ">>", $filename) or die "Could not open file for writing.\n";

    for (my $i=0; $i < @deleted; $i++){
        say $fh $deleted[$i][0].",".$deleted[$i][1];
    }

    print "Backed up deleted messaging preferences to file $filename.";
}
sub RestoreDeletedPreferences {
    my $count = 0;
    my @methods = @_;

    my $dbh = C4::Context->dbh();
    open(my $fh, "<", $filename) or die "Could not open file for writing.\n";

    my $query = "INSERT INTO borrower_message_transport_preferences (borrower_message_preference_id, message_transport_type) VALUES (?,?)";
    my $sth = $dbh->prepare($query);

    # check if user has specified methods (types)
    if (@methods > 0) {
        while (my $line = <$fh>) {
            my @vars = split(',',$line);
            my @remlinebreak = split('\\n', $vars[1]);
            my $pref_id = $vars[0];
            my $type = $remlinebreak[0];

            if (grep(/$type/,@methods)) {
                $sth->execute($pref_id, $type) or $count--;
                $count++;
            }
        }
    } else {
        # simply walk through each line and restore every single line
        while (my $line = <$fh>) {
            my @vars = split(',',$line);
            next if @vars == 0;
            my @remlinebreak = split('\\n', $vars[1]);
            next if not defined $remlinebreak[0];
            my $pref_id = $vars[0];
            my $type = $remlinebreak[0];

            $sth->execute($pref_id, $type) or $count--;
            $count++;
        }
    }

    print "Restored $count preferences.\n";

}
