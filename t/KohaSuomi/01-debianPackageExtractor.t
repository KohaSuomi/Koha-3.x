#!/usr/bin/perl

use Modern::Perl;
use Test::More;

use C4::KohaSuomi::DebianPackages;

#Start testing if we extracted the files we need correctly.
my $packageNames = C4::KohaSuomi::DebianPackages::getDebianPackageNames();

subtest "Are the starting and ending results what we expect", sub {
    is($packageNames->[0], 'libalgorithm-checkdigits-perl');
    is($packageNames->[1], 'libanyevent-http-perl');
    is($packageNames->[-2], 'xmlstarlet');
    is($packageNames->[-1], 'yaz');
};

subtest "Unwanted packages excluded", sub {
    foreach my $unwantedPackageName (@{C4::KohaSuomi::DebianPackages::getDislikedPackageRegexps()}) {
        my $found = 0;
        foreach my $packName (@$packageNames) {
            $found = 1 if $packName =~ /^$unwantedPackageName$/i;
        }
        ok(not($found), "$unwantedPackageName");
    }
};

subtest "Drop package references to other virtual packages", sub {
    my $found = 0;
    foreach my $packName (@$packageNames) {
        $found = 1 if $packName =~ /(?:misc:Depends)|(?:\$)/i;
    }
    ok(not($found), "Virtual packages dropped");
};


my $ksPackageNames = C4::KohaSuomi::DebianPackages::getKohaSuomiDebianPackageNames();
subtest "KohaSuomi specific debian packages discovered", sub {
    #These are discovered
    foreach my $ksPackName (qw(nano curl)) {
        my $found = 0;
        foreach my $packName (@$ksPackageNames) {
            $found = 1 if $packName =~ /^$ksPackName$/i;
        }
        ok($found, "$ksPackName discovered");
    }
    #These must no be discovered
    foreach my $ksPackName (qw(.README)) {
        my $found = 0;
        foreach my $packName (@$ksPackageNames) {
            $found = 1 if $packName =~ /^$ksPackName$/i;
        }
        ok(not($found), "$ksPackName not discovered");
    }
};


