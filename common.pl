#
# Run an executable with system() but check its exit value for errors and
# report error code status to STDERR.
# 
# Returns 0 on successful system() execution and non-zero on error.  Caller
# is still responsible for checking to see if the system() call returned an
# errror or not by checking the return value of this function.
#
sub runCommand
{
  my($command) = shift;
  my($ret) = system($command);
  if($ret != 0)
  {
    if ($? == -1) {
      print STDERR "failed to execute: $!\n";
    }
    elsif ($? & 127) {
      printf STDERR "child died with signal %d, %s coredump\n", ($? & 127),  ($? & 128) ? 'with' : 'without';
    }
    else {
      printf STDERR "child exited with value %d\n", $? >> 8;
    }
  }
  return $ret;
}

#
# Dump files are in the format of <revisionNumber>.dmp.  This function
# returns the revisionNumber for the filename.
#
sub numFromDumpFile {
  my($filename) = shift;
  my($num) = $filename =~ /(\d+)/;
  return $num;
}

#
# Get the last revision number from a dump file directory.
#
sub getLastRev
{
  my($dir) = shift;
  opendir(my $dh, $dir) || die "can't opendir $dir: $!";
  my(@dumps) = sort {numFromDumpFile($a) <=> numFromDumpFile($b)} grep { /\d+\.dmp$/ } readdir($dh);
  closedir $dh;
  
  my($lastRev);
  foreach my $dumpfile (@dumps) {
    $lastRev = numFromDumpFile($dumpfile);
  }
  
  return $lastRev;
}

1;
