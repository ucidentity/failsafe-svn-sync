#
# Read the first properties section of a svndump file.
#
# Pass in a file handle to the dump file.
#
# Returns the properties section as a text string, as it appears in the dump
# file.
#
# Note this everything from the starting Revision-number: line down to
# PROPS-END line is returned, so technically there is more here than just
# "properties."
#
sub readProps()
{
  my($fh) = shift;
  
  my($props) = "";
  my($inProps) = 0;
  while(<$fh>) {
    if(!$inProps && /^Revision-number: /) {
      $inProps = 1;
    }
    if($inProps && /^PROPS-END$/)
    {
      $inProps = 0;
      return $props;
    }
    elsif($inProps) {
      $props .= $_;
    }
  }
  
  return $props;
}

#
# Get the commit message from a properties string returned by readProps().
#
sub getCommitMessage
{
  my($props) = shift;
  
  if($props =~ /(\nsvn:log\nV (\d+)\n)/m) {
    return substr($props, index($props, $1) + length($1), $2), "\n";
  }
  
  return undef;
}

1;
