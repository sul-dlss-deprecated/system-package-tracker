# Load in the server xml files showing current state of each server.
class Import::Servers
  require 'yaml'
  require 'logger'

  SERVER_FILES  = '/var/lib/package-reports/*.yaml'.freeze
  LOGFILE       = 'log/import.log'.freeze
  LOGLEVEL      = Logger::INFO

  # Read the files for checked in servers, parse them out, and then save the
  # current state of servers and their packages to the database.
  def servers
    package_types = %w(yum gem)
    status_types = %w(installed pending)

    servers = []
    servers_update = []
    packages_new = []
    server_packages = {}
    package_ids = {}
    Dir.glob(SERVER_FILES).sort.each do |yaml_file|
      server_yaml = YAML.load(File.open(yaml_file))

      hostname = server_yaml['system']['hostname']
      os_release = server_yaml['system']['release']
      os_family = generate_os_family(os_release)
      last_checkin = server_yaml['system']['lastrun']

      if Server.exists?(hostname: hostname)
        log.info("Servers: Updating #{hostname}")
        servers_update << [hostname, os_release, os_family, last_checkin]
      else
        log.info("Servers: Adding #{hostname}")
        servers << [hostname, os_release, os_family, last_checkin]
      end
      server_packages[hostname] = []

      # For each package, make sure it's not already in the database and add
      # it to the list of packages to add if not.
      package_types.each do |type|
        status_types.each do |status|
          next unless server_yaml[type].key?(status)
          server_yaml[type][status].each_key do |pkg|

            # Work around temporary bug in the package reports where they don't
            # get the correct data structure.  Remove a week after 2016-06-03.
            next if server_yaml[type][status][pkg].is_a?(Array)

            arch = server_yaml[type][status][pkg]['arch'] || 'none'
            server_yaml[type][status][pkg]['version'].each do |version|
              server_packages[hostname] << [pkg, version, arch, type, status,
                                            os_family]

              pkey = pkg + ' ' + version + ' ' + arch + ' ' + type + ' ' +
                     os_family
              next if package_ids.key?(pkey)
              package = Package.find_by(name: pkg, version: version, arch: arch,
                                        provider: type, os_family: os_family)
              if package.nil?
                log.info("Servers: Adding Package #{pkg}")
                packages_new << [pkg, version, arch, type, os_family]
              else
                package_ids[pkey] = package.id
              end
            end
          end
        end
      end
    end

    # Load all hostnames and packages.
    log.info('Servers: *** Importing new servers')
    columns = %w(hostname os_release os_family last_checkin)
    Server.import(columns, servers)
    log.info('Servers: *** Importing new packages')
    columns = %w(name version arch provider os_family)
    Package.import(columns, packages_new.uniq)

    # Update server to package associations by deleting any associations for
    # our found servers and then importing a new list of associations.
    # TODO: It would be cleaner to only remove no longer existing associations.
    delete_server_packages = []
    import_server_packages = []
    server_packages.each_key do |hostname|
      server = Server.find_by(hostname: hostname)
      delete_server_packages << server.id
      server_packages[hostname].each do |p|
        name, version, arch, provider, status, os_family = p
        pkey = name + ' ' + version + ' ' + arch + ' ' + provider + ' ' +
               os_family
        unless package_ids.key?(pkey)
          package = Package.find_by(name: name, version: version, arch: arch,
                                    provider: provider, os_family: os_family)
          package_ids[pkey] = package.id
        end
        package_id = package_ids[pkey]
        import_server_packages << [server.id, package_id, status]
        log.info("Servers: Linking #{hostname} to #{name}, #{version}")
      end
    end
    log.info('Servers: *** Clearing old server packages')
    ServerToPackage.delete_all(server_id: delete_server_packages)
    log.info('Servers: *** Refreshing server packages')
    columns = %w(server_id package_id status)
    ServerToPackage.import(columns, import_server_packages)

    # Update any server information that has changed.
    log.info('Servers: *** Updating existing servers')
    ActiveRecord::Base.transaction do
      servers_update.each do |update|
        hostname, os, os_family, last_checkin = update
        update_settings = { os_release: os,
                            os_family: os_family,
                            last_checkin: Time.zone.at(last_checkin) }
        Server.where(hostname: hostname).update_all(update_settings)
      end
    end
  end

  # Take a hostname, os release, and the time a yaml report was generated.
  # Use these to create or update a server record, along with clearing all
  # packages for that record so that new packages may be updated.
  def save_server(hostname, os_release, last_checkin)
    server = Server.find_or_create_by(hostname: hostname)
    server.os_release = os_release
    server.last_checkin = last_checkin

    server.servers_to_packages.clear
    server.save

    log.info("Servers: Added/updated #{server.hostname}")
    server
  end

  # Given the OS release (a full string of specific OS family plus release
  # version), return a one-word string that can be used as the more general
  # family of os (centos, rhel, etc).
  def generate_os_family(os_release)
    return 'rhel' if /^Red Hat Enterprise Linux/ =~ os_release
    return 'centos' if /^CentOS/ =~ os_release

    'unknown'
  end

  # Wrapper for doing logging of our import statuses for debugging.
  def log
    if @logger.nil?
      @logger = Logger.new(LOGFILE, 'monthly')
      @logger.level = LOGLEVEL
    end
    @logger
  end
end
