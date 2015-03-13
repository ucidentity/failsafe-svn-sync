#!/usr/bin/perl -w

# Usage: separateDumpFiles.pl <inputDumpFile> <outputDirectory>

#
# Take a dump file from svnrdump or svndump and separate out each revision into a separate dump file.
#
# This is for the syncRepo.pl script, which expects each revision to be in
# its own dump file.
#
# This is particularly useful for the initial "full" download of a
# repository using svnrdump or svndump.
#
# Author: Brian Koehmstedt
#

use strict;

if($#ARGV < 1)
{
  print STDERR "Usage: separateDumpFiles.pl <inputDumpFile> <outputDirectory>\n";
  exit 1;
}

open(IN, "<$ARGV[0]") || die "Couldn't open $ARGV[0]";

# capture header
my($header);
for my $i (0 .. 3) {
  $_ = <IN>;
  $header .= $_;
}

my($CURR_DMP) = "/tmp/current.dmp";

open(my $fh, ">$CURR_DMP") || die "Couldn't open $CURR_DMP";

my($rev);
while(1) {
  $rev = &readRevision($rev);
  if(!defined($rev)) {
    last;
  }
}

close(IN);

sub readRevision {
  my($curRev) = shift;
  my($newRev);
  $_ = <IN>;
  my($line) = $_;
  while(defined($line))
  {
    if($line =~ (/^Revision-number: (.*)/))
    {
      $newRev = $1;
      last;
    }
    else
    {
      print $fh $_;
    }
    $_ = <IN>;
    $line = $_;
  }

  close($fh);
  if(defined($curRev))
  {
    &processCurrentDumpFile($curRev);
  }
  if(defined($line))
  {
    open($fh, ">$CURR_DMP") || die "Couldn't open $CURR_DMP";
    print $fh $header;
    print $fh $line;
  }
  return $newRev;
}

sub processCurrentDumpFile {
  my($rev) = shift;
  
  print "Processing $rev\n";
  system("cp $CURR_DMP $ARGV[1]/$rev.dmp");
}
