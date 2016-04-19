class Import
  class Packages
    class Yum
      require 'rpm'

      # Given a centos package version, parse out and return the major OS release
      # it is meant for.  If the version doesn't include the information needed
      # to figure that, return a 0.
      def centos_package_major_release(version)
        m = /\.(el|centos|rhel)(\d)/i.match(version)
        return 0 if m.nil?
        m[2].to_i
      end

      # The centos advisory package includes an os_release field, but only one.
      # At the same time it can have fixes for multiple releases.  Parse out each
      # release to find the EL part of the R_M filename, and return a list of all
      # relevant versions.
      def used_release?(packages, valid_releases = [5, 6, 7])
        packages.each do |package|
          m = /^(.+)-([^-]+)-([^-]+)\.(\w+)\.rpm$/.match(package)
          return true if m.nil?
          package_subver = m[3]

          # Get the major release from the package name and see if it matches one
          # of the versions we care about.  If we can't get the major release,
          # assume that it matches.
          release = centos_package_major_release(package_subver)
          return true if release == 0
          return true if valid_releases.include?(release)
        end

        false
      end

      # Take a single package name that has a yum advisory filed against it, then
      # parse out that name and find any packages with that name.  Check to see
      # which ones are before the patched version and mark any of those packages
      # as falling under the advisory.
      def check_yum_package(adv, advisory_package)
        m = /^(.+)-([^-]+)-([^-]+)\.(\w+)\.rpm$/.match(advisory_package)
        package_name = m[1]
        package_version = m[2]
        package_subver = m[3]
        package_architecture = m[4]
        return nil if package_architecture == 'src'

        os_family = adv.os_family
        advisory_ver = RPM::Version.new(package_version + '-' + package_subver)
        Package.where(name: package_name, arch: package_architecture,
                      provider: 'yum', os_family: os_family).find_each do |p|
          # Skip this package unless it's for the same major release as the
          # advisory package.
          package_release = centos_package_major_release(p.version)
          next if package_release && !used_release?([advisory_package],
                                                    [package_release])

          # And finally check to see if the package is older than the patched
          # version from the advisory, associating them if not.
          check_ver = RPM::Version.new(p.version)
          adv.advisories_to_packages.create(package_id: p.id) \
            if advisory_ver.newer?(check_ver)
        end
      end
    end
  end
end
