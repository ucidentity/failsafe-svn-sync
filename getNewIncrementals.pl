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

require "common.pl";

if($#ARGV < 1) {
  print STDERR "Usage: getNewIncrementals.pl <remoteUrl> <dumpFileOutputDir>\n";
  exit 1;
}

my($remoteUrl) = $ARGV[0];
my($dumpDir) = $ARGV[1];

my($currentRev) = `svn info $remoteUrl|egrep "^Revision: "` =~ /Revision: (.*)/;
my($lastRev) = &getLastRev() + 1;

print "Retrieving from $lastRev to $currentRev\n";

foreach my $rev ($lastRev .. $currentRev) {
  print "Retrieving r$rev\n";
  if(runCommand("svnrdump --non-interactive --incremental -r$rev dump $remoteUrl > /tmp/$rev.dmp")) {
    unlink("/tmp/$rev.dmp");
    die "Couldn't retrieve rev $rev from $remoteUrl";
  }
  
  if(runCommand("mv /tmp/$rev.dmp $dumpDir")) {
    die "Couldn't move /tmp/$rev.dmp to $dumpDir";
  }
  
  print "Successfully wrote $dumpDir/$rev.dmp\n";
}

#
# Get the last revision number from our dump file directory.
#
sub getLastRev
{
  my($dir) = $dumpDir;
  opendir(my $dh, $dir) || die "can't opendir $dir: $!";
  my(@dumps) = sort {numFromDumpFile($a) <=> numFromDumpFile($b)} grep { /\d+\.dmp$/ } readdir($dh);
  closedir $dh;
  
  my($lastRev);
  foreach my $dumpfile (@dumps) {
    $lastRev = numFromDumpFile($dumpfile);
  }
  
  return $lastRev;
}
