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
      server.servers_to_packages.each do |package_map|
        package = Package.find(package_map.package_id)
        name = package.name
        provider = package.provider

        # Create data structure if we've not yet encountered this provider or
        # package.
        if !@report[server.hostname].key?(provider)
          @report[server.hostname][provider] = {}
          @report[server.hostname][provider][name] = {}
          @report[server.hostname][provider][name]['version'] = []
        elsif !@report[server.hostname][provider].key?(name)
          @report[server.hostname][provider][name] = {}
          @report[server.hostname][provider][name]['version'] = []
        end

        # Add the version.
        @report[server.hostname][provider][name]['version'] << package.version

        # See if there are any advisories for this package.
        # TODO: Add more information aside from just the advisory name.
        package.advisories_to_packages.each do |advisory_map|
          advisory = Advisory.find(advisory_map.advisory_id)
          unless @report[server.hostname][provider][name].key?('advisories')
            @report[server.hostname][provider][name]['advisories'] = []
          end
          @report[server.hostname][provider][name]['advisories'] << advisory.name
        end
      end
    end
  end

  # TODO: Flesh this out.
  # Create a report on all servers that have pending updates.  This should
  # show the servers with pending updates, the names and versions of those
  # files, and any advisories linked to those updates.
  def updates
  end
end
