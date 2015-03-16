Mirror a remote subversion repository locally.

If you have no problem being able to run `svnrdump` and `svnadmin load` to
mirror a repository, or using `svnsync`, then just use that.

These scripts were created to overcome some problems with a remote
subversion repository.  If you need to do any of the following, these
scripts may help:

* Separate out svrdump files into separate files for each revision.
  See [separateDumpFiles.pl](separateDumpFiles.pl).

* Overcome a remote repository that is denying access to a repo's root URL,
  effectively forcing you to dump one repository as three separate
  repositories (a repo for /trunk, /branches, /tags each).

* Merge those repositories back into one for your local mirror.
  See [combineSameRevisionDumpFiles.pl](combineSameRevisionDumpFiles.pl).

* Overcome svnrdump files that have problematic revisions in them that are
  causing svnadmin load to fail on said problematic revisions. 
  See [syncRepo.pl](syncRepo.pl).
  * This isn't for fixing massive corruption problems and overcoming lost
    data.  It was designed to overcome dump file loading problems for a
    repository where just a few revisions out of thousands were problematic,
    mainly due to directory renaming.
