#!/usr/bin/perl

# This file is part of Koha.
#
# Copyright Anonymous
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

=head SYNOPSIS

Running this script rebuilds claimletters and removes stale ones.

Valid parameters:

=cut
use Modern::Perl;

use CGI;

use C4::OPLIB::Claiming qw(removeStaleOdts processODUECLAIM);
use C4::Output qw(output_html_with_http_headers);

my $input = new CGI;

C4::OPLIB::Claiming::removeStaleOdts();
C4::OPLIB::Claiming::processODUECLAIM();

C4::Output::output_html_with_http_headers($input, undef, undef);