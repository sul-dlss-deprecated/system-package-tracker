# This is a simple script to get a list of currently installed packages and
# pending upgrades on a RHEL-based system.  It uses a system command to do the
# heavy lifting, and just gathers the information into a data structure then
# dumps it to yaml.

module MCollective
  module Agent
    class Packagereport<RPC::Agent
      action 'yaml' do
        require 'open3'
        require 'yaml'
        require 'socket'

        # The repoquery command is more friendly for parsing than yum directly.  Use
        # it and a custom query format to make parsing out fields easier.
        repoquery = '/usr/bin/repoquery'
        queryformat = '%{NAME} %{EPOCH} %{VERSION} %{RELEASE} %{ARCH}'

        gemquery = '/usr/bin/gem'

        # Data structure for the final report we'll dump.
        report = Hash.new
        report['yum'] = Hash.new
        report['yum']['installed'] = Hash.new
        report['yum']['pending'] = Hash.new
        report['gem'] = Hash.new
        report['gem']['installed'] = Hash.new

        # First we want some general system information.
        hostname = Socket.gethostname
        now = Time.now
        release = File.read('/etc/redhat-release')
        release.chomp!
        report['system'] = Hash.new
        report['system']['hostname'] = hostname
        report['system']['release'] = release
        report['system']['lastrun'] = now.to_i

        # Find the currently installed packages.
        stdin, stdout, stderr, wait_thr = Open3.popen3(repoquery, '-qa',
                                                       '--installed',
                                                       '--queryformat',
                                                       queryformat)
# Comment this out until we're all using ruby >= 1.9, as older popen3 doesn't
# have the wait_thr return value.
#        if wait_thr.exitstatus != 0
#          reply.fail "failed running repoquery: #{stderr}", 1
#        end

        # And go through to add each entries to a hash.
        while line = stdout.gets do
          package, epoch, version, release, arch = line.split(' ')
          fullversion = epoch + ':' + version + '-' + release

          report['yum']['installed'][package] = Hash.new
          report['yum']['installed'][package]['arch'] = arch
          report['yum']['installed'][package]['version'] = Array.new
          report['yum']['installed'][package]['version'] << fullversion
        end

        # Now do this again, but for updates.
        stdin, stdout, stderr, wait_thr = Open3.popen3(repoquery, '-qa',
                                                       '--pkgnarrow=updates',
                                                       '--queryformat',
                                                       queryformat)
#        if wait_thr.exitstatus != 0
#          reply.fail "failed running repoquery: #{stderr}", 1
#        end

        while line = stdout.gets do
          package, epoch, version, release, arch = line.split(' ')
          fullversion = epoch + ':' + version + '-' + release

          report['yum']['pending'][package] = Hash.new
          report['yum']['pending'][package]['arch'] = arch
          report['yum']['pending'][package]['version'] = Array.new
          report['yum']['pending'][package]['version'] << fullversion
        end

        # Now get the list of installed gems.
        stdin, stdout, stderr, wait_thr = Open3.popen3(gemquery, 'list',
                                                       '--local')
#        if wait_thr.exitstatus != 0
#          reply.fail "failed running repoquery: #{stderr}", 1
#        end

        # The gem list format will have each package on a line, followed by
        # the version or versions in parentheses.  If there's more than one
        # version, it will be comma-and-space delimited.
        while line = stdout.gets do
          m = /^(\S+) \((.+)\)$/.match(line)
          next if m.nil?

          package = m[1]
          for version in m[2].split(', ')

            # Initialize fields if this is the first time we've seen the gem.
            if !report['gem']['installed'].key?(package)
              report['gem']['installed'][package] = Hash.new
              report['gem']['installed'][package]['version'] = Array.new
            elsif !report['gem']['installed'][package].key?('version')
              report['gem']['installed'][package]['version'] = Array.new
            end

            report['gem']['installed'][package]['version'] << version
          end
        end

        reply[:report] = report.to_yaml

      end
    end
  end
end

