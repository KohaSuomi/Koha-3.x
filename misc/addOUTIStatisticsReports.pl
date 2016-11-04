#!/usr/bin/perl
# Add OUTI checkout statistics reports to Koha.
# Written by Miika Jokela (OTT/OUTI-Libraries) / Pasi Korkalo (Koha-Suomi Oy)

# GNU GPL version 3 or later applies, for full license text see:
# https://www.gnu.org/licenses/gpl.html

# These reports use the tables created by
# generate_outi_checkout_statistics.pl, so make sure you have
# that set up as a cronjob if you intend to use these reports.

use utf8;
use strict;
use C4::Context;

my $dbh=C4::Context->dbh();

$dbh->do("INSERT INTO

saved_sql ( date_created,
            last_modified,
            last_run,
            borrowernumber,
            type,
            cache_expiry,
            public,
            report_area,
            report_group,
            report_subgroup,
            report_name,
            notes,
            savedsql )

VALUES    ( NOW() , NOW() , NULL , '0' , '1' , '300' , '1' , NULL , 'CIRC' , '' ,

'OUTI kirjastokohtainen vuositason lainatilasto' ,
'Vuositason lainatilasto, poistettu EITILASTO, parametrina annetaan vuosi ja kirjasto. Mukana lainassa olevat ja uusinnat.' ,

'SELECT branch, tyyppi, year, SUM(summa) AS lkm
FROM summatilasto
WHERE branch = <<Kirjasto|branches>>
AND year = <<Vuosi>>
GROUP BY branch, tyyppi, year'

);"
);

$dbh->do("INSERT INTO

saved_sql ( date_created,
            last_modified,
            last_run,
            borrowernumber,
            type,
            cache_expiry,
            public,
            report_area,
            report_group,
            report_subgroup,
            report_name,
            notes,
            savedsql )

VALUES    ( NOW() , NOW() , NULL , '0' , '1' , '300' , '1' , NULL , 'CIRC' , '' ,

'OUTI kirjastokohtainen kuukausitason lainatilasto' ,
'Kuukausitason lainatilasto, poistettu EITILASTO, parametrina annetaan vuosi, kuukausi ja kirjasto. Mukana lainassa olevat ja uusinnat.' ,

'SELECT a.branch, b.branchname, a.tyyppi, a.year, a.month, SUM(a.summa) AS lkm
FROM summatilasto a, branches b
WHERE a.branch = (\@Foo := <<Kirjasto|branches>>)
AND a.year = (\@Vuosi := <<Vuosi>>)
AND a.month = (\@Kuukausi := <<Kuukausi>>)
AND a.branch = b.branchcode
GROUP BY a.branch, b.branchname, a.tyyppi, a.year, a.month
UNION ALL
SELECT a.branch, b.branchname, \"Yhteensä\", a.year, a.month, SUM(a.summa) AS lkm
FROM summatilasto a, branches b
WHERE a.branch = \@Foo
AND a.year = \@Vuosi
AND a.month = \@Kuukausi
AND a.branch = b.branchcode
GROUP BY a.branch, b.branchname, a.year, a.month'

);"
);

$dbh->do("INSERT INTO

saved_sql ( date_created,
            last_modified,
            last_run,
            borrowernumber,
            type,
            cache_expiry,
            public,
            report_area,
            report_group,
            report_subgroup,
            report_name,
            notes,
            savedsql )

VALUES    ( NOW() , NOW() , NULL , '0' , '1' , '300' , '1' , NULL , 'CIRC' , '' ,

'OUTI kaikkien kirjastojen kuukausitason lainatilasto' ,
'Kuukausitason lainatilasto, poistettu EITILASTO, parametrina annetaan vuosi ja kuukausi, kaikki kirjastot summattuna yhteen. Mukana lainassa olevat ja uusinnat.' ,

'SELECT description, year, month, SUM(summa) AS lkm
FROM summatilasto
WHERE year = <<Vuosi>>
AND month = <<Kuukausi>>
GROUP BY description, year, month'

);"
);

# The following two reports are specific to Oulun kaupunginkirjasto

$dbh->do("INSERT INTO

saved_sql ( date_created,
            last_modified,
            last_run,
            borrowernumber,
            type,
            cache_expiry,
            public,
            report_area,
            report_group,
            report_subgroup,
            report_name,
            notes,
            savedsql )

VALUES    ( NOW() , NOW() , NULL , '0' , '1' , '300' , '1' , NULL , 'CIRC' , '' ,

'OUKA kuukausitasoinen lainatilasto' ,
'Lainatilasto, jossa vuosi ja kuukausi annetaan parametreina. Vain Oulun kaupunginkirjaston yksiköt.' ,

'SELECT a.branch, b.branchname, a.tyyppi, a.year, a.month, SUM(a.summa) AS lkm
FROM summatilasto a, branches b
WHERE a.year = (\@Vuosi := <<Vuosi>>)
AND a.month = (\@Kuukausi := <<Kuukausi>>)
AND a.branch = b.branchcode
AND b.branchcode LIKE \"OU%\"
GROUP BY a.branch, b.branchname, a.tyyppi, a.year, a.month
UNION ALL
SELECT a.branch, b.branchname, \"Yhteensä\", a.year, a.month, SUM(a.summa) AS lkm
FROM summatilasto a, branches b
WHERE a.year = \@Vuosi
AND a.month = \@Kuukausi
AND a.branch = b.branchcode
AND b.branchcode like \"OU%\"
GROUP BY a.branch, b.branchname, a.year, a.month
ORDER BY 1,2,3'

);"
);

$dbh->do("INSERT INTO

saved_sql ( date_created,
            last_modified,
            last_run,
            borrowernumber,
            type,
            cache_expiry,
            public,
            report_area,
            report_group,
            report_subgroup,
            report_name,
            notes,
            savedsql )

VALUES    ( NOW() , NOW() , NULL , '0' , '1' , '300' , '1' , NULL , 'CIRC' , '' ,

'OUKA kuukausitasoinen hyllypaikkakohtainen lainatilasto' ,
'Lainatilasto, jossa vuosi, kuukausi ja hyllypaikka annetaan parametreina. Vain Oulun kaupunginkirjaston yksiköt.',

'SELECT a.branch, b.branchname, a.tyyppi, a.year, a.month, SUM(a.summa) AS lkm
FROM summatilasto2 a, branches b
WHERE a.year = (\@Vuosi := <<Vuosi>>)
AND a.month = (\@Kuukausi := <<Kuukausi>>)
AND a.location = (\@Location := <<Hyllypaikka>>)
AND a.branch = b.branchcode
AND b.branchcode like \"OU%\"
GROUP BY a.branch, b.branchname, a.tyyppi, a.year, a.month
UNION ALL
SELECT a.branch, b.branchname, \"Yhteensä\", a.year, a.month, sum(a.summa) AS lkm
FROM summatilasto2 a, branches b
WHERE a.year = \@Vuosi
AND a.month = \@Kuukausi
AND a.location = \@Location
AND a.branch = b.branchcode
AND b.branchcode like \"OU%\"
GROUP BY a.branch, b.branchname, a.year, a.month
ORDER BY 1,2,3'

);"
);

