#!/usr/bin/perl

use DBI;
use DBD::mysql;

# CONFIG VARIABLES
my $user = "";
my $pw = "";

# DATA SOURCE NAME
my $dsn = "dbi:mysql:ssn:0.0.0.0:3306";

my $dsn_temp = "dbi:mysql:savonlinna_temp:0.0.0.0:3306";

# PERL DBI CONNECT
my $connect_ssn = DBI->connect($dsn, "", "");
my $connect_koha_temp = DBI->connect($dsn_temp, $user, $pw);


# PREPARE THE QUERY
my $query = "INSERT INTO ssn (ssnvalue) VALUES (?)";
my $insert = $connect_ssn->prepare($query);

my $query2 = "SELECT TRIM(tunnus) FROM asiakkaat WHERE tunnus != '' GROUP BY tunnus";
my $select = $connect_koha_temp->prepare($query2);

$select->execute;
my $validatedCount = 0;
my $all = 0;
$|=1;
while (my ($tunnus)= $select->fetchrow){
    $all++;
    if(_validateSsn($tunnus)) {
    	$validatedCount++;
    	$insert->execute($tunnus);
    	print "SSN : $tunnus\n";
    }
}

print "All: $all\n";
print "Validated: $validatedCount\n";

sub _validateSsn {
    my $ssnvalue = shift;

    #Valid check marks.
    my $checkmarkvalues = "0123456789ABCDEFHJKLMNPRSTUVWXY";

    if ($ssnvalue =~ /(\d{6})[-+AB](\d{3})(.)/) {
        my $digest = $1.$2;
        my $checkmark = $3;

        my $checkmark_index = $digest % 31;
        my $checkmark_expected = substr $checkmarkvalues, $checkmark_index, 1;

        if ($checkmark eq $checkmark_expected) {
            return 1;
        }
    }
    return 0;
}
