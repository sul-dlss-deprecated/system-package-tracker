# All reporting methods for our servers, packages, and advisories.
class Report
  # Create a hash report of all servers and their installed packages.  If
  # given an optional hostname, limit the search to that one host.
  def installed_packages(hostname = '')
    report = {}
    Server.where("last_checkin > ?", 7.days.ago).find_each do |server|
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
  def advisories(hostname = '', search_package = '')
    report = {}
    package_cache = {}
    Server.where("last_checkin > ?", 7.days.ago).find_each do |server|
      next unless hostname == '' || /#{hostname}/ =~ server.hostname

      packages = {}
      server.installed_packages.each do |package|
        next unless search_package == '' || /#{search_package}/ =~ package.name

        name = package.name
        version = package.version
        arch = package.arch
        provider = package.provider

        pkey = name + ' ' + version + ' ' + arch + ' ' + provider
        package_cache[pkey] = advisory_report(package) \
          unless package_cache.key?(pkey)
        #advisories = package_cache[pkey]
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
  def advisories_by_package(search_package = '')
    report = {}
    Package.find_each do |package|
      next unless search_package == '' || /#{search_package}/ =~ package.name
      next if package.servers.count == 0
      next if package.advisories.count == 0

      name = package.name
      version = package.version
      arch = package.arch
      provider = package.provider
      report[name] = {} unless report.key?(name)
      report[name][version] = {} unless report[name].key?(version)
      report[name][version][arch] = {} unless report[name][version].key?(arch)
      report[name][version][arch][provider] = {} \
        unless report[name][version][arch].key?(name)

      # Add the number of advisories for this package/version.
      advisories = package.advisories.count
      report[name][version][arch][provider]['advisories'] = advisories

      # Add the list of servers that have this package installed.
      report[name][version][arch][provider]['servers'] = []
      package.servers.each do |server|
        report[name][version][arch][provider]['servers'].push(server.hostname)
      end
    end

    report
  end

private

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
end
