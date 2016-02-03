class ImportController < ApplicationController
  require 'yaml'
  
  hostname = 'test.stanford.edu'
  package_types = ['yum', 'gem']

  server = Server.find_or_create_by(hostname: hostname)
  server.servers_to_packages.clear

  server_packages = YAML::load(File.open('/tmp/servers.yaml'))
  for type in package_types
    server_packages[type]['installed'].each_key do |pkg|
      arch = server_packages[type]['installed'][pkg]['arch']
      if !arch
        arch = 'none'
      end
      for version in server_packages[type]['installed'][pkg]['version']
        p = Package.find_or_create_by(name: pkg, version: version, 
                                      arch: arch, provider: type)
                                  
        p.servers_to_packages.create(server_id: server.id)
      end
    end
  end

  # Now purge all packages that no longer are on the server.

  
end
