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
    package_types = ['yum', 'gem']

    # Temporary testing -- assume a hostname.
    hostname = 'test.stanford.edu'

    # Get the host record and then clear any existing packages.
    server = Server.find_or_create_by(hostname: hostname)
    server.servers_to_packages.clear

    # TODO: Stop assuming one file and instead open all files in a directory,
    # one by one.
    # Go through the yaml file for a server, adding any missing packages to
    # the database and then associating them with the server.
    server_packages = YAML::load(File.open('/tmp/servers.yaml'))
    for type in package_types
      server_packages[type]['installed'].each_key do |pkg|

        # arch is only set for yum-provided files and not gems, so set a 
        # default.
        arch = server_packages[type]['installed'][pkg]['arch']
        if !arch
          arch = 'none'
        end

        # Go through each package version (gem can have multiple) to add and
        # associate.
        for version in server_packages[type]['installed'][pkg]['version']
          p = Package.find_or_create_by(name: pkg, version: version, 
                                        arch: arch, provider: type)
                                  
          p.servers_to_packages.create(server_id: server.id)
        end
      end
    end
  end  
end
