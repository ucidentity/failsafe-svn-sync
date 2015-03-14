#!/usr/bin/perl -w

# Usage: separateDumpFiles.pl <outputDirectory> <inputDumpFile>

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
  print STDERR "Usage: separateDumpFiles.pl <outputDirectory> <inputDumpFiles>\n";
  exit 1;
}

# globals
my $fh;
my($CURR_DMP) = "/tmp/current.dmp";

foreach my $i (1 .. $#ARGV)
{
  open(IN, "<$ARGV[$i]") || die "Couldn't open $ARGV[$i]";
  
  # capture header
  my($header);
  for my $i (0 .. 3) {
    $_ = <IN>;
    $header .= $_;
  }
  
  open($fh, ">$CURR_DMP") || die "Couldn't open $CURR_DMP";
  
  my($rev);
  while(1) {
    $rev = &readRevision($rev, $header);
    if(!defined($rev)) {
      last;
    }
  }
  
  close(IN);
}

sub readRevision {
  my($curRev) = shift;
  my($header) = shift;
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
  system("cp $CURR_DMP $ARGV[0]/$rev.dmp");
}
