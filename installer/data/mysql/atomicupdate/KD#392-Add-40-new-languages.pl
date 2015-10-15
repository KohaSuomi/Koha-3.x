#!/usr/bin/perl

# Copyright Open Source Freedom Fighters
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

use C4::Context;
use Koha::AtomicUpdater;

my $dbh = C4::Context->dbh();
my $atomicUpdater = Koha::AtomicUpdater->new();

unless($atomicUpdater->find('#392')) {
    # Albanian
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'sq', 'language', 'Albanian',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'sq', 'alb')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'sq', 'language', 'en', 'Albanian')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'sq', 'language', 'sq', 'Shqipëria')");
    
    # Amharic
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'am', 'language', 'Amharic',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'am', 'amh')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'am', 'language', 'en', 'Amharic')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'am', 'language', 'am', 'አማርኛ')");
    
    # Aramaic
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'arc', 'language', 'Aramaic',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'arc', 'arc')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'arc', 'language', 'en', 'Aramaic')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'arc', 'language', 'arc', 'Arāmāyā')");
    
    # Bengali
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'bn', 'language', 'Bengali',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'bn', 'ben')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'bn', 'language', 'en', 'Bengali')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'bn', 'language', 'bn', 'বাংলা')");
    
    # Bosnian
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'bs', 'language', 'Bosnian',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'bs', 'bos')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'bs', 'language', 'en', 'Bosnian')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'bs', 'language', 'bn', 'Bosanci')");
    
    # Burmese
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'my', 'language', 'Burmese',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'my', 'bur')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'my', 'language', 'en', 'Burmese')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'my', 'language', 'my', 'မြန်မာစာ')");
    
    # Cornish
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'kw', 'language', 'Cornish',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'kw', 'cor')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'kw', 'language', 'en', 'Cornish')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'kw', 'language', 'kw', 'Kernowek')");
    
    # Croatian
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'hr', 'language', 'Croatian',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'hr', 'hrv')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'hr', 'language', 'en', 'Croatian')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'hr', 'language', 'hr', 'hrvatski')");
    
    # Esperanto
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'eo', 'language', 'Esperanto',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'eo', 'epo')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'eo', 'language', 'en', 'Esperanto')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'eo', 'language', 'eo', 'Esperanto')");
    
    # Faroese
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'fo', 'language', 'Faroese',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'fo', 'fao')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'fo', 'language', 'en', 'Faroese')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'fo', 'language', 'fo', 'føroyskt')");
    
    # Finno-Ugric
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'fiu', 'language', 'Finno-Ugric',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'fiu', 'fiu')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'fiu', 'language', 'en', 'Finno-Ugric')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'fiu', 'language', 'fiu', 'Finno-Ugrian')");
    
    # Georgian
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'ka', 'language', 'Georgian',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'ka', 'geo')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'ka', 'language', 'en', 'Georgian')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'ka', 'language', 'ka', 'ქართული')");
    
    # Greek, Ancient
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'grc', 'language', 'Greek, Ancient',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'grc', 'grc')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'grc', 'language', 'en', 'Greek, Ancient')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'grc', 'language', 'grc', 'Ἑλληνική')");
    
    # Indic
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'inc', 'language', 'Indic',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'inc', 'inc')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'inc', 'language', 'en', 'Indic')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'inc', 'language', 'inc', 'Indic')");
    
    # Iranian
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'ira', 'language', 'Iranian',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'ira', 'ira')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'ira', 'language', 'en', 'Iranian')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'ira', 'language', 'ira', 'Iranian')");
    
    # Irish
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'ga', 'language', 'Irish',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'ga', 'gle')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'ga', 'language', 'en', 'Irish')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'ga', 'language', 'ga', 'Gaeilge')");
    
    # Greenlandic
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'kl', 'language', 'Greenlandic',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'kl', 'kal')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'kl', 'language', 'en', 'Greenlandic')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'kl', 'language', 'kl', 'Kalaallisut')");
    
    # Kazakh
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'kk', 'language', 'Kazakh',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'kk', 'kaz')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'kk', 'language', 'en', 'Kazakh')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'kk', 'language', 'kk', 'қазақ тілі')");
    
    # Kurdish
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'ku', 'language', 'Kurdish',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'ku', 'kur')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'ku', 'language', 'en', 'Kurdish')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'ku', 'language', 'ku', 'کوردی')");
    
    # Latvian
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'lv', 'language', 'Latvian',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'lv', 'lav')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'lv', 'language', 'en', 'Latvian')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'lv', 'language', 'lv', 'Latviešu valoda')");
    
    # Lithuanian
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'lt', 'language', 'Lithuanian',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'lt', 'lit')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'lt', 'language', 'en', 'Lithuanian')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'lt', 'language', 'lt', 'lietuvių kalba')");
    
    # Mayan
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'myn', 'language', 'Mayan',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'myn', 'myn')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'myn', 'language', 'en', 'Mayan')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'myn', 'language', 'myn', 'Mayan')");
    
    # Mongolian
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'mn', 'language', 'Mongolian',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'mn', 'mon')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'mn', 'language', 'en', 'Mongolian')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'mn', 'language', 'mn', 'Mongɣol kele')");
    
    # Nepali
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'ne', 'language', 'Nepali',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'ne', 'nep')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'ne', 'language', 'en', 'Nepali')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'ne', 'language', 'ne', 'नेपाली भाषा')");
    
    # Punjabi
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'pa', 'language', 'Punjabi',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'pa', 'pan')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'pa', 'language', 'en', 'Punjabi')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'pa', 'language', 'pa', 'پنجابی')");
    
    # Pashto
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'ps', 'language', 'Pashto',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'ps', 'pus')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'ps', 'language', 'en', 'Pashto')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'ps', 'language', 'ps', 'پښتو')");
    
    # Sanskrit
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'sa', 'language', 'Sanskrit',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'sa', 'san')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'sa', 'language', 'en', 'Sanskrit')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'sa', 'language', 'sa', 'saṃskṛtam')");
    
    # Scottish Gaelic
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'gd', 'language', 'Scottish Gaelic',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'gd', 'gla')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'gd', 'language', 'en', 'Scottish Gaelic')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'gd', 'language', 'gd', 'Gàidhlig')");
    
    # Slovak
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'sk', 'language', 'Slovak',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'sk', 'slo')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'sk', 'language', 'en', 'Slovak')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'sk', 'language', 'sk', 'slovenský')");
    
    # Slovene
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'sl', 'language', 'Slovene',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'sl', 'slv')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'sl', 'language', 'en', 'Slovene')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'sl', 'language', 'sl', 'slovenščina')");
    
    # Somali
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'so', 'language', 'Somali',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'so', 'som')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'so', 'language', 'en', 'Somali')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'so', 'language', 'so', 'Af-Soomaali')");

    # Sotho
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'st', 'language', 'Sotho',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'st', 'sot')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'st', 'language', 'en', 'Sotho')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'st', 'language', 'st', 'Sesotho')");
    
    # Swahili
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'sw', 'language', 'Swahili',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'sw', 'swa')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'sw', 'language', 'en', 'Swahili')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'sw', 'language', 'sw', 'Kiswahili')");
    
    # Standard Tibetan
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'bo', 'language', 'Standard Tibetan',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'bo', 'tib')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'bo', 'language', 'en', 'Standard Tibetan')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'bo', 'language', 'bo', 'ལྷ་སའི་སྐད་')");
    
    # Welsh
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'cy', 'language', 'Welsh',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'cy', 'wel')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'cy', 'language', 'en', 'Welsh')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'cy', 'language', 'cy', 'Cymraeg')");
    
    # Vietnamese
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'vi', 'language', 'Vietnamese',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'vi', 'vie')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'vi', 'language', 'en', 'Vietnamese')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'vi', 'language', 'vi', 'Tiếng Việt')");
    
    # Votic
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'vot', 'language', 'Votic',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'vot', 'vot')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'vot', 'language', 'en', 'Votic')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'vot', 'language', 'vot', 'vađđa ceeli')");
    
    # Yiddish
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'yi', 'language', 'Yiddish',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'yi', 'yid')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'yi', 'language', 'en', 'Yiddish')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'yi', 'language', 'yi', 'יידיש')");
    
    # Yupik
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'ypk', 'language', 'Yupik',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'ypk', 'ypk')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'ypk', 'language', 'en', 'Yupik')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'ypk', 'language', 'ypk', 'Yupik')");
    
    print "Upgrade done (KD#392: Add 40 new languages)\n";
}
