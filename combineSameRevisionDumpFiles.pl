#!/usr/bin/perl -w

#
# Usage: combineSameRevisionDumpFile.pl <outdir> <dumpFileDirectory1> <dumpFileDirectory2> ... [dumpFileDirectoryN]
#

#
# If you have branches, tags and trunk as three different repositories
# because the upstream server is denying access to the repository root, this
# script can merge the dump files from those three repositories into one,
# which can then be loaded as a single repository containing trunk, tags and
# branches.
#
# This expects each revision to have its own dump file, as produced by the
# separateDumpFiles.pl or getNewIncrementals.pl scripts.
#
# This also epects that the revisions from each of the three repositories
# (trunk, branches, tags) match up.  This script is not for merging
# different repositories with different revisions.
#
# Author: Brian Koehmstedt
#

use strict;

my($inc) = $ENV{_} =~ /(.*)\/(.*)$/;
require "$inc/common.pl";

if($#ARGV < 2) {
  print STDERR "Must specify at least two dump file directory locations.\n";
  print STDERR "Usage: combineSameRevisionDumpFile.pl <outdir> <dumpFileDirectory1> <dumpFileDirectory2> ... [dumpFileDirectoryN]\n";
  exit 1;
}

my($lastRev);
foreach my $i (1 .. $#ARGV) {
  my($dir) = $ARGV[$i];
  if(!defined($lastRev)) {
    $lastRev = &getLastRev($dir);
  }
  else {
    my($thisDirLastRev) = &getLastRev($dir);
    if($thisDirLastRev ne $lastRev) {
      die "$dir has a different last revision than the others.  All the dump directory revisions should match.";
    }
  }
}

print "Using last revision $lastRev\n";

my($outdir) = $ARGV[0];

my($currentRev) = &getLastRev("$outdir/dumpFiles");
if(defined($currentRev)) {
  $currentRev++;
}
else {
  $currentRev = 0;
}
 
foreach my $rev ($currentRev .. $lastRev) {
  print "Combining revision $rev\n";
  
  my($uuid);
  my($header);
  my($properties);
  my(@entries);
  foreach my $i (1 .. $#ARGV) {
    my($dir) = $ARGV[$i];
    open(my $fh, "<$dir/$rev.dmp") || die "Couldn't open $dir/$rev.dmp";
    my($thisFileHeader) = &readHeader($fh);
    my($thisFileUuid) = $thisFileHeader =~ /UUID: (\S+)/;
    if(!defined($header)) {
      $header = $thisFileHeader;
    }
    if(!defined($uuid)) {
      $uuid = $thisFileUuid;
    }
    else {
      if($thisFileUuid ne $uuid) {
        die "$dir/$rev.dmp has a different UUID than the others";
      }
    }
    
    # the properties section
    my($thisFileProperties);
    while(<$fh>) {
      my($line) = $_;
      if($line eq "PROPS-END\n")
      {
        $thisFileProperties .= $_;
        if(!defined($properties)) {
          $properties = $thisFileProperties;
        }
        else {
          if($thisFileProperties ne $properties) {
            #die "$dir/$rev.dmp has a different properties section";
            print STDERR "Warning: $dir/$rev.dmp has a different properties section";
          }
        }
        last;
      }
      else {
        $thisFileProperties .= $_;
      }
    }
    
    # the rest of the file, containing the entries
    my($entryText);
    while(<$fh>) {
      $entryText .= $_;
    }
    push(@entries, $entryText);
    
    close($fh);
  }
  
  mkdir("$outdir/dumpFiles", 0755);
  print "Writing to $outdir/dumpFiles/$rev.dmp\n";
  open(my $fh, ">$outdir/dumpFiles/$rev.dmp");
  print $fh $header;
  print $fh $properties;
  foreach my $entry (@entries) {
    print $fh $entry;
  }
  close($fh);
}

sub readHeader
{
  my($fh) = shift;
  
  my($header);
  for my $i (0 .. 3) {
    $_ = <$fh>;
    $header .= $_;
  }
  return $header;
}
