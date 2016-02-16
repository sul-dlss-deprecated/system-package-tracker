# This handles reporting methods, only taking the data that's already in the
# database and presenting it for various functions.
class DisplayController < ApplicationController

  # Do a full dump of all servers, their packages, and the packages'
  # advisories.  This is then displayed as a yaml file, meant to be used by
  # other data sources, or just to debug.
  def index
    @report = {}
    Server.find_each do |server|
      @report[server.hostname] = {}

      # Go through each package.  In some cases (gems) there may be multiple
      # versions of a package on the machine.
      server.servers_to_packages.find_each do |package_map|
        next unless package_map.status == 'installed'
        package = Package.find(package_map.package_id)
        name = package.name
        provider = package.provider

        # Create data structure if we've not yet encountered this provider or
        # package.
        if !@report[server.hostname].key?(provider)
          @report[server.hostname][provider] = {}
          @report[server.hostname][provider][name] = []
        elsif !@report[server.hostname][provider].key?(name)
          @report[server.hostname][provider][name] = []
        end

        # Add the version.
        @report[server.hostname][provider][name] << package.version
      end
    end
  end

  # Create a report on all servers that have advisories.  This should show
  # the servers with advisories, the names and versions of the affected
  # packages, and the version required to fix the advisory.
  def advisories
    @report = {}
    Server.find_each do |server|

      # Go through each package.  In some cases (gems) there may be multiple
      # versions of a package on the machine.
      packages = {}
      server.servers_to_packages.find_each do |package_map|
        next unless package_map.status == 'pending'
        package = Package.find(package_map.package_id)
        name = package.name
        provider = package.provider

        # See if there are any advisories for this package.
        advisories = []
        package.advisories_to_packages.find_each do |advisory_map|
          advisory = Advisory.find(advisory_map.advisory_id)

          advisory_report = {}
          advisory_report['name'] = advisory.name
          advisory_report['synopsis'] = advisory.synopsis
          advisory_report['issue_date'] = advisory.issue_date
          advisory_report['kind'] = advisory.kind
          advisory_report['severity'] = advisory.severity

          # Filter out to show only the fixed packages that match the current
          # package.
          fixed = []
          advisory.fix_versions.split("\n").each do |fixed_package|
            m = /^(.+)-([^-]+)-([^-]+)\.(\w+)\.rpm$/.match(fixed_package)
            next unless m[1] == name
            next unless m[4] == package.arch
            fixed.push(m[2] + '-' + m[3])
          end
          advisory_report['fix_versions'] = fixed.join("\n")

          advisories << advisory_report
        end

        unless advisories.empty?
          unless packages.key?(package.name)
            packages[package.name] = {}
          end
          packages[package.name][package.version] = advisories
        end
      end
      unless packages.empty?
        @report[server.hostname] = packages
      end
    end
  end

  # Create a report on all servers that have pending updates.  This should
  # show the servers with pending updates and the names and versions of those
  # files.
  def updates
    @report = {}
    Server.find_each do |server|

      # Go through each package.  In some cases (gems) there may be multiple
      # versions of a package on the machine.
      packages = {}
      server.servers_to_packages.find_each do |package_map|
        next unless package_map.status == 'pending'
        package = Package.find(package_map.package_id)

        if !packages.key?(package.name)
          packages[package.name] = []
        end

        new = {}
        new['provider'] = package.provider
        new['version'] = package.version
        packages[package.name] << new
      end
      unless packages.empty?
        @report[server.hostname] = packages
      end
    end
  end
end
