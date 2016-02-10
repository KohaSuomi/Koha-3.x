package t::db_dependent::Api::V1::Lists;

# Copyright 2016 KohaSuomi
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

use Modern::Perl;
use Test::More;

#POST /api/v1/lists/{listname}/contents 404
sub post_n_contents404 {
    ok(1, "skipped");
}
sub post_n_contents200 {
    ok(1, "skipped");
}
sub delete_n_contents404 {
    ok(1, "skipped");
}
sub delete_n_contents200 {
    ok(1, "skipped");
}

1;