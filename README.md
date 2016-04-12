[![Build Status](https://travis-ci.org/sul-dlss/system-package-tracker.svg?branch=master)](https://travis-ci.org/sul-dlss/system-package-tracker) | [![Coverage Status](https://coveralls.io/repos/github/sul-dlss/system-package-tracker/badge.svg?branch=master)](https://coveralls.io/github/sul-dlss/system-package-tracker?branch=master)

# System Package Tracker

This is a rails app meant to be run from the command line, with the purpose of
reading in system package information and advisory information, then building
reports alerting users about any current security advisories.

The system works by consuming a YAML file from each individual server, saved in
a central directory.  This is currently provided by an mcollective job, though
the system doesn't care how those files get there.  They contain some basic
system information such as hostname and OS, then one or more package structures
that list the packages on the system and their versions.  Those are pulled into
a database.

A separate set of jobs then run, one per advisory source, to load in the
advisories for that source and then associate them with any relevant packages.

Finally, we can send regular reports of the advisory status per package or per
host, or dump out the advisory state into a YAML file for other programs to
use.

# Adding New Package Types

There are currently two package types, 'gem' and 'yum'.  Adding additional
types of packages can be done just by editing app/models/import/servers.rb
and adding another value to the package_types array.  Then have the scripts
that provide the package lists from servers provide a stanza using that value
and listing off the packages and their status.

An example mcollective script is available under examples/packagereport.rb.
Here's an excerpt of its output as an example:

  gem:
    installed:
      json:
        version:
          - "1.5.5"
      stomp:
        version:
          - "1.3.2"
  yum:
    installed:
      policycoreutils:
        version:
          - "0:2.0.83-24.el6"
        arch: x86_64
      dracut:
        version:
          - "0:004-356.el6"
        arch: noarch
    pending:
      dracut:
        version:
          - "0:004-388.el6"
        arch: noarch

It's laid out with the ability to have multiple versions in case of things like
gems that may have multiple copies installed on a system.  For things such as
yum that have an easy way to find out a list of pending updates, we also have
both the installed stanza and an optional pending stanza under each package
provider.  And lastly, the arch is also optional, based on whether it's
meaningful for a package type.

So if you wanted to do something that handled Debian packages, you'd need to
first add something like the following to the package listing scripts:

  debian:
    installed:
      mypackage:
        version:
          - "1.5"
        arch: noarch
    pending:
      mypackage:
        version:
          - "1.6"
        arch: noarch

Then add 'debian' to package_types in app/models/import/servers.rb.  At that
point the system will start reading the debian stanza in any server files and
loading that data into the package table.  The system will work happily and
report on those packages, though that will only load the packages themselves
and not yet do anything to handle advisories for the new package type.

# Adding New Advisories

Advisories pick up from that point in taking a data source for a package type,
or a package type and os, and then matching those to an advisory source.  In
the case of gemfiles there is only one advisory source, but in the case of yum
packages we have two separate sources -- one for RHEL and one for CentOS.

The packaging classes are available under app/models/import/packages/.  There
are currently classes for Ruby Gems, RHEL yum advisories, and CentOS Yum
advisories.  Loading and refreshing data is done by rake tasks under the
import:* namespace.

Writing a new class can be done fairly easily by modelling on the existing
classes.  Each class should provide two methods, neither accepting any options:

## update_source

This function should get a clean update of information from whatever source
we get advisory data from, storing it to local disk.

## import_advisories

This function should do all of the work of checking the advisory data, loading
it into the database, and then associating that data with packages.  Any data
updates should be accompanied by logging to help debug problems or status.  It
should search for packages based on a unique package type, or if it shares
duties with another advisory source like RHEL and CentOS do for yum, it should
use a unique package type plus OS.  You shouldn't ever have multiple advisory
sources for one package.
