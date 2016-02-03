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

  def index
    package_types = %w(yum gem)

    Dir.glob('/tmp/packages/*.yaml').each do |yaml_file|
      server_yaml = YAML.load(File.open(yaml_file))

      # Get the host record and then clear any existing packages.
      hostname = server_yaml['system']['hostname']
      server = Server.find_or_create_by(hostname: hostname)
      server.servers_to_packages.clear
      server.os_release = server_yaml['system']['release']
      server.save

      # Go through the yaml file for a server, adding any missing packages to
      # the database and then associating them with the server.
      package_types.each do |type|
        server_yaml[type]['installed'].each_key do |pkg|
          arch = server_yaml[type]['installed'][pkg]['arch'] || 'none'

          # Go through each package version (gem can have multiple) to add and
          # associate.
          server_yaml[type]['installed'][pkg]['version'].each do |version|
            p = Package.find_or_create_by(name: pkg, version: version,
                                          arch: arch, provider: type)

            p.servers_to_packages.create(server_id: server.id)
          end
        end
      end
    end
  end
end
