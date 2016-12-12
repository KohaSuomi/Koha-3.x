package C4::KohaSuomi::DebianPackages;

use Modern::Perl;

my @dislikedPackageRegexps = (
    'apache.*', 
    'idzebra.*',
    'mysql.*',  
    'memcached',
);
sub getDislikedPackageRegexps {
    return \@dislikedPackageRegexps;
}

sub getDebianPackageNames {
    return
    _dropUnwantedPackages(
        _extractPackageDependencies(
            _pickNeededPackages(
                _splitToPackages(
                    _slurpControlFile()
                ),
                'koha-perldeps', 'koha-deps'
            )
        ),
        \@dislikedPackageRegexps,
    );
}

sub getKohaSuomiDebianPackageNames {
    return 
    _mergeDebianPackagesLists(
        discoverKohaSuomiDebianPackages(),
        getDebianPackageNames(),
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

sub _dropUnwantedPackages {
    my ($packageNames, $unwanteds) = @_;

    foreach my $unwantedRegexp (@$unwanteds) {
        @$packageNames = grep { $_ if ($_ !~ /$unwantedRegexp/ &&
                                       $_ !~ /\$/) #Also drop package references
                              } @$packageNames;
    }

    return $packageNames;
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


