#!/usr/bin/perl

# This short script removes breaking 000 fields from NORMARC

# Unix:
# marcfix.pl inputfile.mrc > outputfile.xml

($input) = @ARGV;

use MARC::Batch;
use MARC::Record;
use MARC::Field;
  
if (not (-f $input)) { die "Input file \"$input\" does not exist!"}
# if (not ($output)) { die "You must specify an output file!"}

my $batch = MARC::Batch->new( 'USMARC', $input );

# turn off strict so process does not stop on errors
$batch->strict_off();

my $rec_count = 0;

while (my $record = $batch->next()) {
   $rec_count++;
   #get all 000s
   my @m000 = $record->field('000');

   $record->delete_field(@m000);

   print $record->as_usmarc();
}

#print "\n$rec_count records processed\n";
#print "----------------------------\n";
# make sure there weren't any problems.
#if ( my @warnings = $batch->warnings() ) {
#       print "\nWarnings were detected!\n", @warnings;
#   }
