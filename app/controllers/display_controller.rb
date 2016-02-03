# This handles reporting methods, only taking the data that's already in the
# database and presenting it for various functions.
class DisplayController < ApplicationController

  # Do a full dump of all servers, their packages, and the packages' 
  # advisories.  This is then displayed as a yaml file, meant to be used by 
  # other data sources, or just to debug.
  def index
    @report = Hash.new
    Server.find_each do |server|
      @report[server.hostname] = Hash.new

      # Go through each package.  In some cases (gems) there may be multiple
      # versions of a package on the machine.
      for package_map in server.servers_to_packages
        package = Package.find(package_map.package_id)
        name = package.name
        provider = package.provider

        # Create data structure if we've not yet encountered this provider or
        # package.
        if !@report[server.hostname].key?(provider)
          @report[server.hostname][provider] = Hash.new
          @report[server.hostname][provider][name] = Hash.new
          @report[server.hostname][provider][name]['version'] = Array.new
        elsif !@report[server.hostname][provider].key?(name)
          @report[server.hostname][provider][name] = Hash.new
          @report[server.hostname][provider][name]['version'] = Array.new
        end

        # Add the version.
        @report[server.hostname][provider][name]['version'] << package.version

        # See if there are any advisories for this package.
        # TODO: Add more information aside from just the advisory name.
        for advisory_map in package.advisories_to_packages
          advisory = Advisory.find(advisory_map.advisory_id)
          if !@report[server.hostname][provider][name].key?('advisories')
            @report[server.hostname][provider][name]['advisories'] = Array.new
          end
          @report[server.hostname][provider][name]['advisories'] << advisory.name
        end
      end
    end
  end

  # TODO - Flesh this out.
  # Create a report on all servers that have pending updates.  This should
  # show the servers with pending updates, the names and versions of those
  # files, and any advisories linked to those updates.
  def updates
  end
  
end
