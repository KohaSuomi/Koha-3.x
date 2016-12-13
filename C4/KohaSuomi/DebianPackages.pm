package C4::KohaSuomi::DebianPackages;

use Modern::Perl;

my %excludedPackageRegexps = (
    Standalone => [ #Prevent configuring any other servers than the core Koha Perl-files and Debian deps
        'apache.*',
        'idzebra.*',
        'mysql.*',
        'memcached',
    ],
    Ubuntu1604 => [ #Skip packages not present in Ubuntu16.04, install them from CPAN
        'libtemplate-plugin-htmltotext-perl',
        'cron-daemon',
    ],
);
my %includedPackages = (
    Ubuntu1604 => [
        'systemd-cron',
        'mariadb-client',
        'mariadb-common',
        'libdbd-mysql-perl',
        'libcurl4-openssl-dev',
    ],
);

sub getPackageRegexps {
    my ($excludedOrIncluded, @listnames) = @_;
    my @listBuilder;
    foreach my $name (@listnames) {
        my $neededList;
        if ($excludedOrIncluded =~ /ex/ && defined($excludedPackageRegexps{$name})) {
            push(@listBuilder, @{$excludedPackageRegexps{$name}});
        }
        elsif ($excludedOrIncluded =~ /in/ && defined($includedPackages{$name})) {
            push(@listBuilder, @{$includedPackages{$name}});
        }
        else {
            die "Unknown \$listname '$name'";
        }
    }
    return \@listBuilder;
}

sub getUbuntu1604PackageNames {
    return
    _mergeDebianPackagesLists(
        getPackageRegexps('include', qw(Ubuntu1604)),
        _dropExcludedPackages(
            getDebianPackageNames(),
            getPackageRegexps('exclude', qw(Ubuntu1604)),
        )
    );
}

sub getDebianPackageNames {
    return
    _dropParentPackageReferences(
        _dropExcludedPackages(
            _extractPackageDependencies(
                _pickNeededPackages(
                    _splitToPackages(
                        _slurpControlFile()
                    ),
                    qw(koha-perldeps koha-deps),
                )
            ),
            getPackageRegexps('exclude', qw(Standalone)),
        )
    );
}

sub getKohaSuomiDebianPackageNames {
    return 
    _mergeDebianPackagesLists(
        discoverKohaSuomiDebianPackages(),
        getUbuntu1604PackageNames(),
    );
}

sub discoverKohaSuomiDebianPackages {
    opendir my $dir, "$ENV{KOHA_PATH}/installer/KohaSuomiPackages/" or die "Cannot open directory: $!";
    my @files = readdir $dir;
    closedir $dir;
    @files = grep {$_ !~ /^\./} @files; #Exclude files starting with .
    return \@files;
}

sub _slurpControlFile {
    open(my $FH, "<:encoding(UTF-8)","$ENV{KOHA_PATH}/debian/control");
    my $control = join("",<$FH>);
    close($FH);
    return $control;
}

sub _splitToPackages {
    my ($control) = @_;

    my @availablePackages = split(/(?=^Package:)/smi, $control);
    return \@availablePackages;
}

sub _pickNeededPackages {
    my ($availablePackages, @neededPackageNames) = @_;
    my @neededPackages;
    foreach my $needPackName (@neededPackageNames) {
        push(@neededPackages, grep {$_ =~ /^Package:\s*$needPackName/gsmi} @$availablePackages);
    }
    return \@neededPackages;
}

sub _extractPackageDependencies {
    my ($packages) = @_;

    my @deps;
    foreach my $package (@$packages) {
        if ($package =~ /^Depends:\s*(.*?)^\w/gsmi) {
            my $deps = $1;
            $deps =~ s/\s//gsmi;
            push(@deps, split(",", $deps));
        }
        else {
            die "Couldn't parse Package:\n'$package'\nUsing regexp /^Depends: (.*?)^\\w/gsmi";
        }
    }
    return \@deps;
}

sub _dropExcludedPackages {
    my ($packageNames, $unwanteds) = @_;

    foreach my $unwantedRegexp (@$unwanteds) {
        @$packageNames = grep { $_ if ($_ !~ /$unwantedRegexp/ &&
                                       $_ !~ /\$/) #Also drop package references
                              } @$packageNames;
    }

    return $packageNames;
}

=head2 _dropParentPackageReferences

Drop the tail from strange dependency entries like this:
    libtest-simple-perl|perl-modules
to be like this:
    libtest-simple-perl

=cut

sub _dropParentPackageReferences {
    my ($packageNames) = @_;

    my @packsAgain;
    foreach my $packName (@$packageNames) {
        #extract libtest-simple-perl|perl-module
        if ($packName =~ /^\s*(.+)\s*(?=\|)/i) {
            push(@packsAgain, $1);
        }
        #extract libtest-deep-perl
        else {
            push(@packsAgain, $packName);
        }
    }
    return \@packsAgain;
}

sub _mergeDebianPackagesLists {
    my (@lists) = @_;
    my @list;
    foreach my $l (@lists) {
        push(@list, @$l);
    }
    return \@list;
}

return 1;

