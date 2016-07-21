#!/usr/bin/perl

use DBI;
use DBD::mysql;

# CONFIG VARIABLES
my $user = "";
my $pw = "";

# DATA SOURCE NAME
my $dsn = "dbi:mysql:ssn:0.0.0.0:3306";

my $dsn_temp = "dbi:mysql::0.0.0.0:3306";

# PERL DBI CONNECT
my $connect_ssn = DBI->connect($dsn, "", "");
my $connect_koha_temp = DBI->connect($dsn_temp, $user, $pw);


# PREPARE THE QUERY

my $query1 = "select b.borrowernumber as borrowernumber, a.tunnus as tunnus from koha.borrowers b
    join koha_temp.asiakasviivakoodit av on b.cardnumber = av.viivakoodi
    join koha_temp.asiakkaat a on av.asiakasId = a.asiakasId where b.branchcode like 'MLI%';";
my $select_temp = $connect_koha_temp->prepare($query1);

my $query2 = "SELECT ssnkey, ssnvalue FROM ssn;";
my $select_ssn = $connect_ssn->prepare($query2);

my $query3 = "INSERT INTO koha.borrower_attributes (borrowernumber, code, attribute) VALUES (?,?,?)";
my $insert = $connect_koha_temp->prepare($query3);

$select_temp->execute;
my $all = 0;
$|=1;
while (my ($borrowernumber,$tunnus)= $select_temp->fetchrow){
    
    $select_ssn->execute;
    while (my ($ssnkey, $ssnvalue)= $select_ssn->fetchrow) {
        if($tunnus eq $ssnvalue) {
            $all++;
            $insert->execute($borrowernumber, 'SSN', 'sotu'.$ssnkey);
            print "Added: sotu".$ssnkey.",".$borrowernumber."\n";
        }
    }
}

print "All: $all\n";