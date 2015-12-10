#!/usr/bin/perl

# The purpose of this script is to go through all the files in the specified directory
# and check their creation dates. After this it deletes all the old files (in other
# words it will only leave the specified amount of the newest files in the wolder).

use strict;
use warnings;
use POSIX;
use Data::Dumper qw/Dumper/;

my $path = "/tmp/test"; #Path to the directory which has the files we are going through
my $amount = 5; #Number of files we are going to leave in the directory

my $files;
my $arrayposition = 0;

opendir(DIR, $path) or die;

#Going through all the files in directory
while(my $file = readdir(DIR)){
	#Use a regular expression to ignore files beginning with a period
    next if ($file =~ m/^\./);

    #To make sure we are dealing with a file
    next unless (-f "$path/$file");

    #Getting files last modification date
    my $stat = (stat("$path/$file"))[8];

    my $fileref = {
    				'filename' => $file,
    				'creationdate' => $stat
    				};

    push @$files, $fileref;
}

#Getting arraysize
my $arraysize = @$files;

#Sorting files from smallest to biggest
for(my $i = 0; $i < $arraysize; $i++){
	for(my $j = $i + 1; $j < $arraysize; $j++){
		if(@$files[$j]->{'creationdate'} < @$files[$i]->{'creationdate'}){
			my $placeholder = @$files[$i];
			@$files[$i] = @$files[$j];
			@$files[$j] = $placeholder;
		}
	}
}

#Delete files that are too old
for(my $i = 0; $i < ($arraysize - $amount); $i++){
	unlink $path."/".@$files[$i]->{'filename'};

	print "File ".$path."/".@$files[$i]->{'filename'}." deleted!\n";
}

closedir(DIR);

exit 0;