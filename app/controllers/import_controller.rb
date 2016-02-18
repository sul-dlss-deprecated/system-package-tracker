# This controls the importing of data from all of our servers.  It's meant to
# go through every server report, adding servers and packages if needed, and
# making sure that each server is associated with the correct packages.
#
# A separate process will run an mcollective job that collects server and
# package information on each of our servers, collect the output, and save it
# to a series of yaml files in a directory, one per server.  This will then
# read those files into the database.
class ImportController < ApplicationController
  require 'yaml'

  # Take a hostname, os release, and the time a yaml report was generated.
  # Use these to create or update a server record, along with clearing all
  # packages for that record so that new packages may be updated.
  def save_server (hostname, os_release, last_checkin)
    server = Server.find_or_create_by(hostname: hostname)
    server.os_release = os_release
    server.last_checkin = last_checkin

    server.servers_to_packages.clear
    server.save

    return server
  end


  def index
    package_types = %w(yum gem)
    status_types = %w(installed pending)

    Dir.glob('/var/lib/package-reports/*.yaml').each do |yaml_file|
      server_yaml = YAML.load(File.open(yaml_file))

      # Get or create a host record.
      hostname = server_yaml['system']['hostname']
      server = save_server(hostname, server_yaml['system']['release'],
	                       server_yaml['system']['lastrun'])

      # Go through the yaml file for a server, adding any missing packages to
      # the database and then associating them with the server.  Packages may
      # be marked either installed or pending (for upgrades not installed).
      package_types.each do |type|
        status_types.each do |status|
          next unless server_yaml[type].key?(status)
          server_yaml[type][status].each_key do |pkg|
            arch = server_yaml[type][status][pkg]['arch'] || 'none'

            # Go through each package version (gem can have multiple) to add
            # and associate.
            server_yaml[type][status][pkg]['version'].each do |version|
              p = Package.find_or_create_by(name: pkg, version: version,
                                            arch: arch, provider: type)

              p.servers_to_packages.create(server_id: server.id,
                                           status: status)
            end
          end
        end
      end
    end
  end
end
