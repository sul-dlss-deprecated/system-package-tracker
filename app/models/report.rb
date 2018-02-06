# All reporting methods for our servers, packages, and advisories.
class Report
  require 'fileutils'

  SCHEDULE = '/etc/server-reports/schedule'.freeze
  PACKAGES = '/etc/server-reports/upgradable-packages'.freeze
  UPGRADE_BASE_DIR = '/var/tmp/package-upgrades'.freeze
  LAST_CHECKIN = 7.days.ago

  # Create a hash report of all servers and their installed packages.  If
  # given an optional hostname, limit the search to that one host.
  def installed_packages(hostname = '')
    report = {}
    Server.where("last_checkin > ?", LAST_CHECKIN).find_each do |server|
      next if hostname != '' && server.hostname != hostname
      report[server.hostname] = {}

      # Go through each package.  In some cases (gems) there may be multiple
      # versions of a package on the machine.
      server.installed_packages.each do |package|
        name = package.name
        provider = package.provider

        # Create data structure if we've not yet encountered this provider or
        # package.
        if !report[server.hostname].key?(provider)
          report[server.hostname][provider] = {}
          report[server.hostname][provider][name] = []
        elsif !report[server.hostname][provider].key?(name)
          report[server.hostname][provider][name] = []
        end

        # Add the version.
        report[server.hostname][provider][name] << package.version
      end
    end

    report
  end

  # Create a report on all servers that have advisories.  This should show
  # the servers with advisories, the names and versions of the affected
  # packages, and the version required to fix the advisory.  This returns a
  # hash that can be used for web or text display.
  def advisories(hostname = '', search_package = '', search_provider = '')
    report = {}
    package_cache = {}
    Server.where("last_checkin > ?", LAST_CHECKIN).find_each do |server|
      next unless hostname == '' || /#{hostname}/ =~ server.hostname

      packages = {}
      server.installed_packages.each do |package|
        next unless search_package == '' || /#{search_package}/ =~ package.name
        next unless search_provider == '' || search_provider == package.provider

        name = package.name
        version = package.version
        arch = package.arch
        provider = package.provider

        pkey = name + ' ' + version + ' ' + arch + ' ' + provider
        package_cache[pkey] = advisory_report(package) \
          unless package_cache.key?(pkey)
        advisories = Marshal.load(Marshal.dump(package_cache[pkey]))

        # Now add any advisories to the record for this package/version.
        next if advisories.empty?
        packages[package.name] = {} unless packages.key?(package.name)
        packages[package.name][package.version] = advisories
      end

      # And if there were any packages, add them to the server.
      next if packages.empty?
      report[server.hostname] = packages
    end

    report
  end

  # Create a report on all servers that have advisories.  This should show
  # the servers with advisories, the names and versions of the affected
  # packages, and the version required to fix the advisory.  This returns a
  # hash that can be used for web or text display.
  def advisories_by_package(search_package = '', search_servers = [],
                            search_provider = '')
    report = {}
    Package.find_each do |package|
      next unless search_package == '' || /#{search_package}/ =~ package.name
      next unless search_provider == '' || search_provider == package.provider
      next if package.servers.count == 0
      next if package.advisories.count == 0

      # Get the servers that this package/version/etc applies to.
      servers = []
      package.servers.each do |server|
        next unless search_servers.empty? || search_servers.include?(server.hostname)
        next unless server.last_checkin
        next unless server.last_checkin > LAST_CHECKIN
        servers << server.hostname
      end
      next unless servers.count > 0

      name = package.name
      version = package.version
      arch = package.arch
      provider = package.provider

      report[name] = {} unless report.key?(name)
      report[name][version] = {} unless report[name].key?(version)
      report[name][version][arch] = {} unless report[name][version].key?(arch)
      report[name][version][arch][provider] = {} \
        unless report[name][version][arch].key?(name)

      advisories = package.advisories.count
      report[name][version][arch][provider]['advisories'] = advisories
      report[name][version][arch][provider]['servers'] = servers
    end

    report
  end

  # Search out packages based on pending updates and sort by the version they
  # would currently go to.  This lets us explicitly set versions to upgrade to,
  # so that we can generate lists of upgrades by month and not be surprised
  # when a new upgrade comes out during the month.
  def updates_by_package(search_package = '', search_servers)
    updates = {}
    Package.find_each do |package|
      next unless search_package == '' || /#{search_package}/ =~ package.name
      next if package.servers.count == 0
      next if package.advisories.count == 0
      next if package.provider == 'gem'

      # Get the servers that this package/version/etc applies to.
      name = package.name
      package.servers.each do |server|
        next unless search_servers.empty? || search_servers.include?(server.hostname)
        next unless server.last_checkin
        next unless server.last_checkin > LAST_CHECKIN

        pending = Package.includes(:pending_packages).find_by(packages: { name: name }, servers: { hostname: server.hostname })
        next if pending.nil?
        updates[name] = {} unless updates.key?(name)
        updates[name][pending.version] = [] \
          unless updates[name].key?(pending.version)
        updates[name][pending.version] << server.hostname
      end
    end

    updates
  end

  # Create a set of files used to upgrade servers via mcollective.  This will
  # be one file with mcollective commands, and a set of per-package files that
  # let mcollective run only against the servers that need the updates.
  def create_upgrade_files(week, search_package = '')

    # Find the directory for the given week.  If it already exists, then give
    # a warning and skip this run.
    time = date_of_next_week_count(week)
    upgradedir = "#{UPGRADE_BASE_DIR}/#{time}/"
    if Dir.exist?(upgradedir)
      warn "Skipping week #{week}, #{upgradedir} already exists"
      return
    else
      FileUtils.mkdir_p(upgradedir)
    end

    # Load the schedule, packages, and servers in the given week.
    schedule = load_schedule
    packages = load_packages
    current_servers = schedule[week]
    raise "No valid servers" if current_servers.empty?

    report = updates_by_package(search_package, current_servers)

    # Open cachefile of packages per server.
    server_upgrades = {}
    cache_fname = UPGRADE_BASE_DIR + '/packages-by-server.yaml'
    server_upgrades = YAML.load_file(cache_fname) if File.readable?(cache_fname)

    runfile_fname = upgradedir + 'run-mco.sh'
    runfile = File.new(runfile_fname, 'w')
    runfile.write("#/bin/bash\n\n")
    runfile.write("# Data for week #{week}\n\n")

    # Go through the upgrade report and split it up into package/version bits.
    report.keys.sort.each do |name|
      next unless packages.empty? || packages.include?(name)
      servers = []
      report[name].keys.each do |upgrade_version|
        servers = report[name][upgrade_version]
        next if servers.empty?

        # Now write the upgrade command and servers to apply it to.
        package_ver = name + '-' + upgrade_version
        pkg_fname = upgradedir + package_ver
        pkgfile = File.new(pkg_fname, 'w')
        servers.uniq!
        servers.sort.each do |server|
          server_upgrades[server] = [] unless server_upgrades.key?(server)
          server_upgrades[server] << package_ver
          pkgfile.write("#{server}\n")
        end
        pkgfile.close
        upgrade = "mco rpc package update package=#{name} " \
          + "version=#{upgrade_version} --nodes #{package_ver}\n"
        runfile.write(upgrade)
      end
    end
    runfile.close
    File.chmod(0755, runfile_fname)

    # Finally save a cache of packages by server name for later.
    cache_fname = UPGRADE_BASE_DIR + '/packages-by-server.yaml'
    cachefile = File.new(cache_fname, 'w')
    cachefile.write(server_upgrades.to_yaml)
    cachefile.close
  end

  # Find out what was done in the previous week's upgrade.  This searches the
  # upgrade dir for all package files and their contents of servers.  It does
  # assume that all upgrades were successful, since parsing the mco output is
  # a bit difficult.
  def last_upgrade
    time = date_of_last_week
    upgradedir = "#{UPGRADE_BASE_DIR}/#{time}/"

    packages = {}
    Dir.foreach(upgradedir) do |fname|
      next if fname =~ /^\./
      next if fname =~ /^run-mco/
      packages[fname] = IO.readlines(upgradedir + fname)
    end

    packages
  end

private

  # Load the schedule of when to upgrade servers, turning into a hash of arrays
  # with hash key the scheduled week (0..4) and the array each server that
  # should be loaded during that week.
  def load_schedule
    schedule = {}
    File.open(SCHEDULE, 'r') do |f|
      f.each_line do |line|
        next unless line =~ /\S/
        line.chomp!
        m = /^(\d+)\s+(\S+)/.match(line)
        next if m.nil?
        week = m[1].to_i
        server = m[2]
        schedule[week] = [] unless schedule.key?(week)
        schedule[week].push(server)
      end
    end

    schedule
  end

  # Load a list of packages that we consider valid for auto-upgrading.  This
  # is just a simple textfile with one package per line.
  def load_packages
    packages = []
    return packages unless File.readable?(PACKAGES)
    File.open(PACKAGES, 'r') do |f|
      f.each_line do |line|
        next unless line =~ /\S/
        line.chomp!
        packages.push(line)
      end
    end

    packages
  end

  # Take a package and convert all advisories that belong to it into a hash,
  # adding a filtered version of the packages that advisory is fixed by.
  def advisory_report(package)
    advisories = []
    package.advisories.uniq.each do |advisory|
      advisory_report = advisory.as_json
      fixed = fixed_versions(advisory, package)
      advisory_report['fix_versions_filtered'] = fixed.join(' ')
      advisories << advisory_report
    end

    advisories
  end

  # An advisory may have fixes for multiple packages.  Given an advisory and
  # a package, filter out all the fixed packages in the advisory save the ones
  # that match the given package.
  def fixed_versions(advisory, package)
    # Gem files only include fixes for one package, so we can just return all.
    return advisory.fix_versions.split("\n") if advisory.os_family == 'gem'

    # Otherwise, find any fixes where the name and arch match the given package.
    fixed = []
    advisory.fix_versions.split("\n").each do |fixed_package|
      m = /^(.+)-([^-]+)-([^-]+)\.(\w+)\.rpm$/.match(fixed_package)
      next unless m[1] == package.name
      next unless m[4] == package.arch
      fixed.push(m[2] + '-' + m[3])
    end

    fixed
  end

  # Use the week number of a given date to calculate a rotating week number
  # from 1-4.
  def find_week_count(count_date)
    week_of_year = count_date.strftime('%V').to_i
    week_count = week_of_year.modulo(4) + 1

    week_count
  end

  # Given a week number of 1-4, calculate the next date for that week number,
  # starting with a fresh cycle from week 1.  In other words, if we aren't
  # currently on a week 1, skip ahead to the next week 1 before starting our
  # count.
  def date_of_next_week_count(find_week)
    current = Time.current
    week_count = find_week_count(current)
    while week_count != 1
      current += 1.week
      week_count = find_week_count(current)
    end

    while week_count != find_week
      current += 1.week
      week_count = find_week_count(current)
    end

    current.strftime('%Y-%V')
  end

  # Find the year and week count for last week, used to get upgrade data.
  def date_of_last_week
    current = Time.current
    current -= 1.week
    current.strftime('%Y-%V')
  end

end
