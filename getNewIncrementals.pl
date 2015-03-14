#!/usr/bin/perl -w

#
# Usage: getNewIncrementals.pl <remoteUrl> <dumpFileOutputDir>
#
# This gets new revisions from upstream and stores them as svndump files in
# the dumpFileOutputDir.  Each revision is stored as a separate dump file.
#
# The svnSync.pl script uses these dump files to update a repository mirror.
#
# Author: Brian Koehmstedt
#

use strict;

use File::Temp qw/ tempdir /;

my($inc) = $ENV{_} =~ /(.*)\/(.*)$/;
require "$inc/common.pl";

if($#ARGV < 1) {
  print STDERR "Usage: getNewIncrementals.pl <remoteUrl> <dumpFileOutputDir>\n";
  exit 1;
}

my($remoteUrl) = $ARGV[0];
my($dumpDir) = $ARGV[1];

my($currentRev) = `svn info $remoteUrl|egrep "^Revision: "` =~ /Revision: (.*)/;
my($lastRev) = &getLastRev($dumpDir) + 1;

if($lastRev <= $currentRev) {
  print "Retrieving from $lastRev to $currentRev\n";
  
  my $tmpdir = tempdir(CLEANUP => 1);
   
  foreach my $rev ($lastRev .. $currentRev) {
    print "Retrieving r$rev\n";
    if(runCommand("svnrdump --non-interactive --incremental -r$rev dump $remoteUrl > $tmpdir/$rev.dmp")) {
      unlink("$tmpdir/$rev.dmp");
      die "Couldn't retrieve rev $rev from $remoteUrl";
    }
    
    if(runCommand("mv $tmpdir/$rev.dmp $dumpDir")) {
      die "Couldn't move $tmpdir/$rev.dmp to $dumpDir";
    }
    
    print "Successfully wrote $dumpDir/$rev.dmp\n";
  }
}
