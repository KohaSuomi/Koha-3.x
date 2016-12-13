#!/usr/bin/perl

use Modern::Perl;

my @badstuff = (
['KD#1036-Add_column_branch_for_payments_transactions.pl', 'KD-1036-Add_column_branch_for_payments_transactions.pl', '#1036'],
['KD#1076-Interface_type_of_implementation_for_online_payments.pl', 'KD-1076-Interface_type_of_implementation_for_online_payments.pl', '#1076'],
['KD#1103-generate-pdf-bills.pl', 'KD-1103-generate-pdf-bills.pl', '#1103'],
['KD#1133_system_preference_for_opacs_prepared_searches.pl', 'KD-1133-system_preference_for_opacs_prepared_searches.pl', '#1133'],
['KD#1134_improve_authorised_values_with_allow_deny_option.pl', 'KD-1134-improve_authorised_values_with_allow_deny_option.pl', '#1134'],
['KD#1446-Add-Vetuma-tables.pl', 'KD-1446-Add-Vetuma-tables.pl', '#1446'],
['KD#1452-syspref-for-anon-othernames.pl', 'KD-1452-syspref-for-anon-othernames.pl', '#1452'],
['KD#1454-individual-password-lengts-for-different-policies', 'KD-1454-individual-password-lengts-for-different-policies', '#1454'],
['KD#1459-kohasuomi-class-sort-rules.pl', 'KD-1459-kohasuomi-class-sort-rules.pl', '#1459'],
['KD#1526-allow-or-deny-renewing-notforloan-items.pl', 'KD-1526-allow-or-deny-renewing-notforloan-items.pl', '#1526'],
['KD#1530-Add-EDItX-procurement-tables.pl', 'KD-1530-Add-EDItX-procurement-tables.pl', '#1530'],
['KD#351-Add-Sami-Romany-and-Icelandic-languages-and-fix-Norwegian.pl', 'KD-351-Add-Sami-Romany-and-Icelandic-languages-and-fix-Norwegian.pl', '#351'],
['KD#377-CPU_Integration-Add_table_for_transactions.pl', 'KD-377-CPU_Integration-Add_table_for_transactions.pl', '#377'],
['KD#392-Add-40-new-languages.pl', 'KD-392-Add-40-new-languages.pl', '#392'],
['KD#636-CPU_Integration-Online_payments.pl', 'KD-636-CPU_Integration-Online_payments.pl', '#636'],
['KD#70-Add-Estonian-and-Karelian-languages.pl', 'KD-70-Add-Estonian-and-Karelian-languages.pl', '#70'],
['KD#90-RedmineSSO.pl', 'KD-90-RedmineSSO.pl', '#90'],
['KD#993-Remove-reserve-payment-from-location.pl', 'KD-993-Remove-reserve-payment-from-location.pl', '#993'],
);


foreach my $bs (@badstuff) {
  my $lolz = `perl atomicupdate.pl -r $bs->[2]`;
  my $lulz = `perl atomicupdate.pl -i 'atomicupdate/'.$bs->[1]`;
}
