#!/usr/bin/perl
# Generate statistics tables for OUTI checkout reports.
# Written by Miika Jokela (OTT/OUTI-Libraries) / Pasi Korkalo (Koha-Suomi Oy)

# GNU GPL3 or later applies. See full license text at:
# https://www.gnu.org/licenses/gpl.html

# Run this script from cron on the first day of month:

# 30 06 1 * * $KOHA_PATH/misc/cronjobs/generate_outi_statistics.pl

# You need OUTI Koha reports for using these tables, run
# misc/addOUTIStatisticsReports.pl to add them to your reports.

use strict;
use C4::Context;

my $dbh = C4::Context->dbh();

# Generate summatilasto

$dbh->do("DROP TABLE summatilasto;");

$dbh->do("CREATE TABLE summatilasto

          (
            `branch` varchar(10) CHARACTER SET utf8 DEFAULT NULL,
            `tyyppi` varchar(15) CHARACTER SET utf8 DEFAULT NULL,
            `description` mediumtext CHARACTER SET utf8,
            `year` int(4) DEFAULT NULL,
            `month` int(2) DEFAULT NULL,
            `source` varchar(16) CHARACTER SET utf8 DEFAULT NULL,
            `summa` bigint(21) NOT NULL DEFAULT '0'
          )

          ENGINE=InnoDB DEFAULT CHARSET=utf8;
;");

$dbh->do("INSERT INTO summatilasto 
          SELECT `a`.`branch` AS `branch`, (CASE `c`.`description`

          WHEN 'CD-äänilevy'           THEN 'AV-aineisto'
          WHEN 'DVD-levy'              THEN 'AV-aineisto'
          WHEN 'CD-ROM'                THEN 'AV-aineisto'
          WHEN 'Blu-ray'               THEN 'AV-aineisto'
          WHEN 'C-kasetti'             THEN 'AV-aineisto'
          WHEN 'MP3-CD'                THEN 'AV-aineisto'
          WHEN 'Videokasetti'          THEN 'AV-aineisto'
          WHEN 'Konsolipeli'           THEN 'AV-aineisto'
          WHEN 'LP-levy'               THEN 'AV-aineisto'
          WHEN 'Single'                THEN 'AV-aineisto'

          WHEN 'Kirja'                 THEN 'Kirjalainat'
          WHEN 'Nuotti'                THEN 'Kirjalainat'
          WHEN 'Kartta'                THEN 'Kirjalainat'
          WHEN 'Työpiirustus'          THEN 'Kirjalainat'

          WHEN 'Moniviestin'           THEN 'Muut lainat'
          WHEN 'Aikakauslehti'         THEN 'Muut lainat'
          WHEN 'Celian äänikirja'      THEN 'Muut lainat'
          WHEN 'Esine'                 THEN 'Muut lainat'
          WHEN 'Dia'                   THEN 'Muut lainat'
          WHEN 'Peli'                  THEN 'Muut lainat'
          WHEN 'Mikrofilmi'            THEN 'Muut lainat'
          WHEN 'Verkkoaineisto'        THEN 'Muut lainat'
          WHEN 'Sanomalehti'           THEN 'Muut lainat'
          WHEN 'E-kirja'               THEN 'Muut lainat'
          
          ELSE 'Luokittelematon' END)  AS `tyyppi`,

          `c`.`description`            AS `description`,
          YEAR(`a`.`datetime`)         AS `year`,
          MONTH(`a`.`datetime`)        AS `month`,
          `a`.`type`                   AS `source`,
          COUNT(`a`.`datetime`)        AS `summa`

          FROM (
            ((`statistics` `a`
            LEFT JOIN `items` `b` ON((`a`.`itemnumber` = `b`.`itemnumber`)))
            LEFT JOIN `itemtypes` `c` ON((`b`.`itype` = `c`.`itemtype`))) 
          )

          WHERE (
            (year(`a`.`datetime`) >= year(now()))
            AND (`a`.`type` IN ('issue','renew'))
            AND ((`a`.`usercode` <> 'EITILASTO') OR ISNULL(`a`.`usercode`))
          )

          GROUP BY `a`.`branch`,
                   `a`.`type`,
                   `c`.`description`,
                   YEAR(`a`.`datetime`),
                   MONTH(`a`.`datetime`);"
);

# Generate summatilasto2

$dbh->do("DROP TABLE summatilasto2;");

$dbh->do("CREATE TABLE `summatilasto2`

          (
            `branch` varchar(10) CHARACTER SET utf8 DEFAULT NULL,
            `tyyppi` varchar(15) CHARACTER SET utf8 DEFAULT NULL,
            `description` mediumtext CHARACTER SET utf8,
            `year` int(4) DEFAULT NULL,
            `month` int(2) DEFAULT NULL,
            `source` varchar(16) CHARACTER SET utf8 DEFAULT NULL,
            `location` varchar(80) CHARACTER SET utf8 DEFAULT NULL,
            `summa` bigint(21) NOT NULL DEFAULT '0'
          )

          ENGINE=InnoDB DEFAULT CHARSET=utf8;"
);

$dbh->do("INSERT INTO summatilasto2
          SELECT `a`.`branch` AS `branch`, (CASE `c`.`description`

          WHEN 'CD-äänilevy'          THEN 'AV-aineisto' 
          WHEN 'DVD-levy'             THEN 'AV-aineisto' 
          WHEN 'CD-ROM'               THEN 'AV-aineisto' 
          WHEN 'Blu-ray'              THEN 'AV-aineisto' 
          WHEN 'C-kasetti'            THEN 'AV-aineisto' 
          WHEN 'MP3-CD'               THEN 'AV-aineisto' 
          WHEN 'Videokasetti'         THEN 'AV-aineisto' 
          WHEN 'Konsolipeli'          THEN 'AV-aineisto'
          WHEN 'LP-levy'              THEN 'AV-aineisto'
          WHEN 'Single'               THEN 'AV-aineisto'

          WHEN 'Kirja'                THEN 'Kirjalainat' 
          WHEN 'Nuotti'               THEN 'Kirjalainat'
          WHEN 'Kartta'               THEN 'Kirjalainat'
          WHEN 'Työpiirustus'         THEN 'Kirjalainat'

          WHEN 'Moniviestin'          THEN 'Muut lainat' 
          WHEN 'Aikakauslehti'        THEN 'Muut lainat'
          WHEN 'Celian äänikirja'     THEN 'Muut lainat'
          WHEN 'Esine'                THEN 'Muut lainat'
          WHEN 'Dia'                  THEN 'Muut lainat' 
          WHEN 'Peli'                 THEN 'Muut lainat'
          WHEN 'Mikrofilmi'           THEN 'Muut lainat'
          WHEN 'Verkkoaineisto'       THEN 'Muut lainat'
          WHEN 'Sanomalehti'          THEN 'Muut lainat' 
          WHEN 'E-kirja'              THEN 'Muut lainat'

          ELSE 'Luokittelematon' END) AS `tyyppi`,

          `c`.`description`           AS `description`,
          year(`a`.`datetime`)        AS `year`,
          month(`a`.`datetime`)       AS `month`,
          `a`.`type`                  AS `source`,
          `b`.`location`              AS `location`,
          count(`a`.`datetime`)       AS `summa` 

          FROM (
            ((`statistics` `a` 
            LEFT JOIN `items` `b` ON((`a`.`itemnumber` = `b`.`itemnumber`))) 
            LEFT JOIN `itemtypes` `c` ON((`b`.`itype` = `c`.`itemtype`)))
          )

          WHERE (
                  (YEAR(`a`.`datetime`) >= YEAR(NOW()))
                  AND (`a`.`type` IN ('issue','renew')) 
                  AND ((`a`.`usercode` <> 'EITILASTO') OR ISNULL(`a`.`usercode`))
                ) 

          GROUP BY `a`.`branch`,
                   `a`.`type`,
                   `c`.`description`,
                   YEAR(`a`.`datetime`),
                   MONTH(`a`.`datetime`),`b`.`location`;"
);
