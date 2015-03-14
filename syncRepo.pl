#!/usr/bin/perl -w

#
# Usage: syncRepo.pl <localRepoDir> <remoteRepo> <dumpFileDir>
#
# <localRepoDir> is the FULL path to your local Subversion mirror repository.
#
# <remoteRepo> is the URL of the upstream repository that you are mirroring.
#
# <dumpFileDir> is the directory full of dump files that you obtained from
# either using separateDumpFiles.pl, getNewIncrementals.pl, or your own
# script to grab incremental svndump files for each upstream revision.
#
# Typically you would do a full svnrdump and separateDumpFiles.pl the first
# time around, and then after that update the directory with
# getNewIncrementals.pl.
#
# Reads in svndump files from dumpFileDir and updates a subversion
# repository mirror.
#
# This script will first try to update the mirror the easy way: by taking an
# incremental dump file and using svnadmin load to load it into the mirror.
#
# But, if that fails, it will try to do it the hard way.  It will fetch a
# FULL dump file (as opposed to an incremental one) from the upstream
# repository at the revision that failed to incrementally load.  It will
# then load this full dump into a local temporary repo, check that out, copy
# the files to a checkout of our previously-loaded revision, do the
# necessary svn "adds" and "deletes", and then a svn commit.  This commits
# all the changes from this one revision to the mirror.  It will then resume
# normal attemps at loading subsequent revisions using incremental dump
# files.
#
# Note that if the "fail safe" way fails, manual intervention will be
# necessary.
#
# Also note that this script can resume where it left off if interrupted,
# with one exception: If the script is interrupted while it's copying files
# to the mirror repository, the mirror repository will enter an
# indeterminant and probable corrupted state.  This script makes an attempt
# at detecting this by using a "dumb lock file" to alert the user that a
# previous run was probably interrupted during the critical copy-to-mirror
# operation.  If this happens,it will probably be a good idea to start over
# with a clean mirror repository (keep all your incremental dump files!).
#
# Author: Brian Koehmstedt
#

require "common.pl";
require "readProps.pl";

if($#ARGV < 2) {
  print STDERR "syncRepo.pl <localRepoDir> <remoteRepo> <dumpFileDir>\n";
  exit 1;
}

my($localRepoDir) = $ARGV[0];
my($remoteRepo) = $ARGV[1];
my($dumpFileDir) = $ARGV[2];

my($COPY_IN_PROGRESS) = "copyinprogress";

my($currentRev) = `svn info file://$localRepoDir|egrep "^Revision: "` =~ /Revision: (.*)/;
if($currentRev > 0) {
  $currentRev++;
}
&findRevisionsToSync($currentRev);

sub findRevisionsToSync
{
  my($dir) = $dumpFileDir;
  my($currentRev) = shift;
  opendir(my $dh, $dir) || die "can't opendir $dir: $!";
  my(@dumps) = sort {numFromDumpFile($a) <=> numFromDumpFile($b)} grep { /\d+\.dmp$/ } readdir($dh);
  closedir $dh;
  
  my($lastRev);
  foreach my $dumpfile (@dumps) {
    $lastRev = numFromDumpFile($dumpfile);
  }
  
  if($currentRev <= $lastRev) {
    print "Loading from $currentRev to $lastRev\n";
    &loadRange($currentRev, $lastRev);
  }
}

sub loadRange {
  my($startRev) = shift;
  my($endRev) = shift;
  my($dir) = $dumpFileDir;
  
  if(-e $COPY_IN_PROGRESS) {
    die "$COPY_IN_PROGRESS file exists, likely indicating that a previous run of this script was killed during a critical copy operation to the primary repository.  This likely means the repository is corrupted.  Build a new empty repository and delete the $COPY_IN_PROGRESS file to start over.";
  }
  
  if(runCommand("rm -rf tmp")) { die; };
  
  my($lastSuccessfulTmpRepoDir);
  for my $rev ($startRev .. $endRev) {
    if(-e $COPY_IN_PROGRESS) {
      die "Copy in progress.  Should not be the case.";
    }
    print "Loading for rev $rev\n";
    # Copy current repository to a temporary location in case the load
    # errors-out midstream.
    if(runCommand("mkdir -p tmp/$rev")) { die; };
    if(!$lastSuccessfulTmpRepoDir)
    {
      if(runCommand("cp -pr $localRepoDir tmp/$rev ") != 0)
      {
        die "Failed to create repo for rev $rev: $?";
      }
    }
    else
    {
      if(runCommand("mv $lastSuccessfulTmpRepoDir tmp/$rev ") != 0)
      {
        die "Failed to create repo for rev $rev: $?";
      }
    }
    
    opendir(my $dh, "tmp/$rev") || die "can't opendir tmp/$rev: $!";
    my(@dirs) = grep { !/^\./ && -d "tmp/$rev/$_" } readdir($dh);
    closedir $dh;
    my($repoName) = $dirs[0];
    
    if(runCommand("svnadmin load tmp/$rev/$repoName < $dir/$rev.dmp") != 0)
    {
      if(runCommand("rm -rf tmp/$rev")) { die; }
      $lastSuccessfulTmpRepoDir = undef;
      print STDERR "Failed to load revision $rev: $?.  Attempting fail-safe load.\n";
      &failSafeLoad($rev, "$dir/$rev.dmp");
      print STDERR "Fail safe load of rev $rev succeeded.\n";
    }
    else
    {
      if(runCommand("touch $COPY_IN_PROGRESS")) { die; }
      if(runCommand("cp -pru tmp/$rev/$repoName/* $localRepoDir")) { die; }
      if(runCommand("rm $COPY_IN_PROGRESS")) { die; }
      $lastSuccessfulTmpRepoDir = "tmp/$rev/$repoName";
    }
  }
}

sub failSafeLoad
{
  my($rev) = shift;
  my($dumpFile) = shift;
  
  open($fh, "<$dumpFile") || die "Couldn't open $dumpFile";
  my($commitMessage) = &getCommitMessage(&readProps($fh));
  close($fh);
  
  print "commitMessage=$commitMessage\n";
  
  my($workdir) = "tmp/full";
  
  if(runCommand("rm -rf $workdir")) {
    die "Couldn't delete $workdir";
  }
  
  if(runCommand("mkdir $workdir")) {
    die "Couldn't make $workdir";
  }
  
  # get the full dump
  if(-e "/tmp/$rev-full.dmp") {
    print "Using /tmp/$rev-full.dmp\n";
    if(runCommand("cp -p /tmp/$rev-full.dmp $workdir/$rev-full.dmp")) {
      die "Couldn't copy /tmp/$rev-full.dmp";
    }
  }
  else
  {
    print "Getting dump file from $remoteRepo\n";
    if(runCommand("svnrdump -r$rev --non-interactive dump $remoteRepo > $workdir/$rev-full.dmp")) {
      die "Couldn't get full dump for rev $rev";
    }
    # If you want to cache these in /tmp
    if(runCommand("cp $workdir/$rev-full.dmp /tmp")) {
      die "Couldn't copy $workdir/$rev-full.dmp to /tmp";
    }
  }
  
  # create the full dump repo
  if(runCommand("svnadmin create $workdir/$rev-repo")) {
    die "Couldn't create $workdir/$rev-repo";
  }
  
  # load the full dump
  if(runCommand("svnadmin load $workdir/$rev-repo < $workdir/$rev-full.dmp")) {
    die "Couldn't load full dump for rev $rev";
  }
  
  # copy last-rev repo to temporary location
  if(runCommand("cp -pr $localRepoDir $workdir/last-rev-repo")) {
    die "Couldn't copy our primary repo to $workdir/last-rev-repo";
  }
  
  # checkout last-rev repo
  if(runCommand("svn checkout file://`pwd`/$workdir/last-rev-repo $workdir/last-rev.checkout")) {
    die "Couldn't checkout $workdir/last-rev-repo";
  }
  
  # checkout full $rev repo
  if(runCommand("svn checkout file://`pwd`/$workdir/$rev-repo $workdir/$rev.checkout")) {
    die "Couldn't checkout $workdir/$rev-repo";
  }
  
  # delete .svn file in $rev.checkout
  if(runCommand("rm -rf $workdir/$rev.checkout/.svn")) {
    die "Couldn't delete .svn file in $workdir/$rev.checkout";
  }
  
  # Rsync new checkout files to our primary checkout directory
  if(runCommand("rsync -av --delete $workdir/$rev.checkout/* $workdir/last-rev.checkout")) {
    die "Couldn't resync from $workdir/$rev.checkout to $workdir/last-rev.checkout";
  }
  
  my($remaining);
  while(($remaining = checkAddsAndDeletes($workdir, $commitMessage)) > 0)
  {
    print "There are still $remaining items left to add or delete.  Iterating again.\n";
  }

  # Do commit
  if(runCommand("svn commit $workdir/last-rev.checkout -m \"$commitMessage\"")) {
    die "Couldn't commit $workdir/last-rev.checkout";
  }
  
  # Post-commit report to confirm directory is "clean".  An empty string
  # should come back from svn status.
  $report = `svn status $workdir/last-rev.checkout`;
  print "POST COMMIT REPORT\n";
  print $report;
  print "END POST COMMIT REPORT\n";
  if($report && length($report) > 0) {
    die "Post commit report still shows messages.";
  }
  
  # Success!  Our last-rev-repo in temporary location now contains the
  # differences for this revision.  Last thing to do is copy it to our
  # permanent location.
  
  if(runCommand("touch $COPY_IN_PROGRESS")) { die; }
  if(runCommand("cp -pru $workdir/last-rev-repo/* $localRepoDir")) { die; }
  if(runCommand("rm $COPY_IN_PROGRESS")) { die; }
}

#
# Check to see which files/directories have been newly copied and deleted
# and will trigger a "svn add" or "svn delete" command for those.
#
sub checkAddsAndDeletes()
{
  my($workdir) = shift;
  my($commitMessage) = shift;
  
  print "PRE ADD AND DELETE REPORT\n";
  my($report);
  $report = `svn status $workdir/last-rev.checkout`;
  print $report;
  my(@lines) = split(/\n/, $report);
  my(@adds);
  my(@deletes);
  foreach my $line (@lines) {
    my($ind, $file) = $line =~ /^(\S)\s+(.*)/;
    if($ind eq "?") {
      # need to add
      push(@adds, $file);
      print "ADD: $file\n";
    }
    elsif($ind eq "!") {
      # need to delete
      push(@deletes, $file);
      print "DELETE: $file\n";
    }
  }
  print "END OF PRE ADD AND DELETE REPORT\n";

  for my $file (@adds) {
      print "Adding $file\n";
      if(runCommand("svn add $file")) {
        die "Couldn't svn add $file";
      }
      print "Done adding $file\n";
  }

  for my $file (@deletes) {
      print "Deleting $file\n";
      if(runCommand("svn delete $file")) {
        die "Couldn't svn delete $file";
      }
      print "Done deleting $file\n";
  }
  
  # Show report again to confirm we caught everything
  $report = `svn status $workdir/last-rev.checkout`;
  print "POST ADD AND DELETE REPORT\n";
  print $report;
  print "END POST ADD AND DELETE REPORT\n";
  @lines = split(/\n/, $report);
  @adds = undef;
  @deletes = undef;
  foreach my $line (@lines) {
    my($ind, $file) = $line =~ /^(\S)\s+(.*)/;
    if($ind eq "?") {
      # need to add
      push(@adds, $file);
    }
    elsif($ind eq "!") {
      # need to delete
      push(@deletes, $file);
    }
  }
  return $#adds + $#deletes;
}
