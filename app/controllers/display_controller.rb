# This handles reporting methods, only taking the data that's already in the
# database and presenting it for various functions.
class DisplayController < ApplicationController

  # Do a full dump of all servers and their packages.
  def index
    @report = Report.new.installed_packages
  end

  # Create a report on all servers that have advisories.  This should show
  # the servers with advisories, the names and versions of the affected
  # packages, and the version required to fix the advisory.
  def advisories
    @report = Report.new.advisories
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
