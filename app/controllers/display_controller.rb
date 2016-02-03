class DisplayController < ApplicationController

  def index
    @report = Hash.new
    Server.find_each do |server|
      @report[server.hostname] = Hash.new
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
        @report[server.hostname][provider][name]['version'] << package.version

        # See if there are any advisories for this package.
        # TODO: Put more useful information here.
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

end
