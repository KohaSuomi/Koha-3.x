#!/usr/bin/perl

#USAGE ls *.png | perl convert_locales.pl
use Locale::Country;


while (<>) {
  my $filename = $_;
  chomp $filename;

  my $code2;
  if ($filename =~ /(\w+?)\.png/) { $code2 = $1; }

  my $code3 = country_code2code($code2, LOCALE_CODE_ALPHA_2, LOCALE_CODE_ALPHA_3);

  if ($code3) {
    my $action = "mv $filename $code3.png";
    system($action);
    print "$action\n";
  }
  else {
    print "NOACTION ".$filename."\n";
  }
}
