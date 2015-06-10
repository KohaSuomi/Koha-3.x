package SImpls::FileUtils;

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
use Carp;
use Test::More;

sub checkRegexpInsideFiles {
    my $C = shift;
    my $data = $C->data;

    ##First cache files to avoid unnecessary file loading
    my %files;
    foreach my $d (@$data) {
        unless ( $files{ $d->{fileName} } ) {
            my $directory = $d->{directory};
            $directory =~ s/\$KOHA_PATH/$ENV{KOHA_PATH}/gsm;
            my $fileContent = File::Slurp::read_file( $directory.$d->{fileName}, {binmode => ':utf8'} )
                                or die "common_stepImpl::checkRegexpInsideFiles():> $!";
            $files{ $d->{fileName} } = $fileContent;
        }
    }

    foreach my $d (@$data) {
        my $fileContent = $files{ $d->{fileName} };
        my $regexp = $d->{recordFindingRegexp};
        last unless ok(($fileContent =~ m/$regexp/u), "File ".$d->{fileName}." matches $regexp");
    }
}

=head findFileFromKoha

    FileUtils::findFileFromKoha('fines.pl');

Finds the given file by name using the find-utility from the $KOHA_PATH-directory.
@RETURNS String, absolute path to the directory where the file is.
=cut

sub findFileFromKoha {
    my ($C, $filename) = @_;

    open(FH, "find /$ENV{KOHA_PATH}/ -iname '$filename' |") or die "FileUtils::findFileFromKoha():> Couldn't find file '$filename' because:\n".$!;
    while (my $filename = <FH>) {
        chomp $filename;
        if ($filename =~ /(blib|etc)/) {
            next();
        }
        ok((-f $filename && -r $filename), "$filename exists and is readable");
        $C->{stash}->{scenario}->{file} = $filename;
        my ($file, $dir) = File::Basename::fileparse($filename);
        return ($file, $dir);
    }
    #If we reach this, we know we haven't found the file we are looking for. So fail this test!
    ok((1 == 0), "Found file '$filename' from '$ENV{KOHA_PATH}' with read permission!")
}

sub findFile {
    my $C = shift;
    my $file = $1;
    $file =~ s/\$KOHA_PATH/$ENV{KOHA_PATH}/gsm;

    ok((-f $file && -r $file), "$file exists and is readable");
    $C->{stash}->{scenario}->{file} = $file;
}

1;
