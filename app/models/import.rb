class Import

  require 'net/http'
  require 'nokogiri'
  require 'rexml/document'
  require 'git'
  require 'find'
  require 'yaml'
  require 'rubygems'
  require 'rpm'
  require 'logger'
  require 'activerecord-import'
  require "activerecord-import/base"
  ActiveRecord::Import.require_adapter('pg')

  SERVER_FILES  = '/var/lib/package-reports/*.yaml'
  LOGFILE       = 'log/import.log'
  LOGLEVEL      = Logger::INFO

  PROXY_ADDR    = 'swp.stanford.edu'
  PROXY_PORT    = 80

  CENTOS_ADV    = 'https://raw.githubusercontent.com/stevemeier/cefs/master/errata.latest.xml'

  RUBY_ADV_GIT = 'https://github.com/rubysec/ruby-advisory-db.git'
  REPORTS_DIR = '/home/reporting/'
  RUBY_ADV_DIR = 'ruby-advisory-db'
  RHEL_ADV_DIR = 'rhel-cvrf'

  def centos_advisories
    # Parse the data and look up.  The file is formatted with every advisory
    # under <opt>.
    xml_data = get_centos_advisories
    doc = REXML::Document.new(xml_data)
    doc.elements.each('opt/*') do |advisory|

      # Skip the meta item, the one thing in the XML that's not an advisory.
      next if advisory.name == 'meta'

      # Any advisory lines that end in -X\d\d\d are all for Xen4CentOS, which
      # we don't run and will give false flags.
      next if /--X\d{3}$/.match(advisory.name)

      # Skip this record if it doesn't include a release we care about.
      packages = []
      advisory.elements.each('packages') do |adv_package|
        packages.push(adv_package.text)
      end
      unless used_release?(packages)
        log.info("CentOS Advisories: Skipping #{advisory.name}, not for any OS releases we use")
        next
      end

      # Add the advisory and then link to any affected packages.
      adv = add_centos_advisory(advisory)
      packages.each do |package|
        check_yum_package(adv, package)
      end
    end
  end

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
#      next unless /sulreports/.match(yaml_file)
      server_yaml = YAML.load(File.open(yaml_file))

      hostname = server_yaml['system']['hostname']
      os_release = server_yaml['system']['release']
      last_checkin = server_yaml['system']['lastrun']

      if Server.exists?(hostname: hostname)
        log.info("Servers: Updating #{hostname}")
        servers_update << [hostname, os_release, last_checkin]
      else
        log.info("Servers: Adding #{hostname}")
        servers << [hostname, os_release, last_checkin]
      end
      server_packages[hostname] = []

      # For each package, make sure it's not already in the database and add
      # it to the list of packages to add if not.
      package_types.each do |type|
        status_types.each do |status|
          next unless server_yaml[type].key?(status)
          server_yaml[type][status].each_key do |pkg|
            arch = server_yaml[type][status][pkg]['arch'] || 'none'
            server_yaml[type][status][pkg]['version'].each do |version|
              server_packages[hostname] << [pkg, version, arch, type, status]

              pkey = pkg + ' ' + version + ' ' + arch + ' ' + type
              next if package_ids.key?(pkey)
              package = Package.find_by(name: pkg, version: version, arch: arch,
                                        provider: type)
              if package == nil
                log.info("Servers: Adding Package #{hostname}")
                packages_new << [pkg, version, arch, type]
              else
                package_ids[pkey] = package.id
              end
            end
          end
        end
      end
    end

    # Load all hostnames and packages.
    log.info("Servers: *** Importing new servers")
    columns = ['hostname', 'os_release', 'last_checkin']
    Server.import(columns, servers)
    log.info("Servers: *** Importing new packages")
    columns = ['name', 'version', 'arch', 'provider']
    Package.import(columns, packages_new.uniq)

    # Update server to package associations by deleting any associations for
    # our found servers and then importing a new list of associations.
    delete_server_packages = []
    import_server_packages = []
    server_packages.each_key do |hostname|
      server = Server.find_by(hostname: hostname)
      delete_server_packages << server.id
      server_packages[hostname].each do |p|
        name, version, arch, provider, status = p
        pkey = name + ' ' + version + ' ' + arch + ' ' + provider
        unless package_ids.key?(pkey)
          package = Package.find_by(name: name, version: version, arch: arch,
                                    provider: provider)
          package_ids[pkey] = package.id
        end
        package_id = package_ids[pkey]
        import_server_packages << [server.id, package_id, status]
        log.info("Servers: Linking #{hostname} to #{name}, #{version}")
      end
    end
    log.info("Servers: *** Clearing old server packages")
    ServerToPackage.delete_all(:server_id => delete_server_packages)
    log.info("Servers: *** Refreshing server packages")
    columns = ['server_id', 'package_id', 'status']
    ServerToPackage.import(columns, import_server_packages)

    # Update any server information that has changed.
    log.info("Servers: *** Updating existing servers")
    ActiveRecord::Base.transaction do
      servers_update.each do |update|
        hostname, os, last_checkin = update
        Server.where(:hostname => hostname).update_all(:os_release => os,
          :last_checkin => Time.at(last_checkin))
      end
    end

    return
  end

  # Search the advisory directory, skipping advisories for gems we don't
  # have installed, and then checking those that we do have installed for
  # matching versions.
  def ruby_advisories
    maintain_ruby_advisory_git()

    advisory_dir = REPORTS_DIR + RUBY_ADV_DIR + '/gems'
    Dir.entries(advisory_dir).sort.each do |gem|
      next if gem == '.' || gem == '..'
      packages = Package.where(name: gem, provider: 'gem')
      unless packages.count > 0
        log.info("Ruby advisories: Skipping #{gem}, no local installs")
        next
      end

      gemdir = "#{advisory_dir}/#{gem}/"
      Dir.glob(gemdir + '*.yml').sort.each do |adv_file|
        advisory = YAML::load(File.open(adv_file))

        # The advisories pull both from CVEs and from OSVDB.  In some cases
        # the advisory will have both, but in most cases the name will be one
        # or the other.
        if advisory['cve'] && advisory['osvdb']
          name = advisory['cve'] + '/' + advisory['osvdb'].to_s
        else
          name = advisory['cve'] || advisory['osvdb']
        end

        # Gather other fields and map to what we care about.
        description = advisory['description']
        issue_date = advisory['date']
        references = advisory['url']
        kind = 'Unknown'
        synopsis = advisory['title']
        severity = advisory['cvss_v2'] || 'Unknown'
        os_family = 'gem'

        # Unaffected versions are equivalent to patched versions to our logic.
        patched_versions = []
        if advisory.key?('patched_versions')
          patched_versions << advisory['patched_versions']
        end
        if advisory.key?('unaffected_versions')
          patched_versions << advisory['unaffected_versions']
        end
        next if patched_versions.count == 0
        fix_versions = patched_versions.join("\n")

        log.info("Ruby advisories: Adding advisory #{name} for #{gem}")
        adv = nil
        if Advisory.exists?(name: name, os_family: os_family)
          adv = Advisory.find_by(name: name, os_family: os_family)
        else
          adv = Advisory.create(name: name,
                                description: description,
                                issue_date: issue_date,
                                references: references,
                                kind: kind,
                                synopsis: synopsis,
                                severity: severity,
                                os_family: os_family,
                                fix_versions: fix_versions)
        end

        # Check each package with this name to see if it is affected by the
        # advisory.  This uses gem formatted requirement strings, so use that
        # to parse if the packages match.
        packages.each do |package|
          matched = 0
          advisory['patched_versions'].each do |version|
            pv = Gem::Version.new(package.version)
            if Gem::Requirement.new(version.split(',')).satisfied_by?(pv)
              log.info("Ruby advisories: Skipping link of #{gem}/#{name} to #{package.name} #{package.version}: patch satisfied by #{version}")
              matched = 1
              break
            end
          end
          unless matched == 1
            log.info("Ruby advisories: Linked #{gem}/#{name} to #{package.name} #{package.version}")
            adv.advisories_to_packages.create(package_id: package.id)
          end
        end
      end
    end
  end

  # Search the advisory directory, skipping advisories for gems we don't
  # have installed, and then checking those that we do have installed for
  # matching versions.
  def rhel_advisories
    advisories = get_rhel_advisories()
    advisories.sort.each do |fname|
      advisory = parse_cvrf(fname)

      # Skip this record if it doesn't include a release we care about.
      unless used_release?(advisory['packages'])
        log.info("RHEL Advisories: Skipping #{advisory['name']}, not for any OS releases we use")
        next
      end

      # Add the advisory and then link to any affected packages.
      adv = add_rhel_advisory(advisory)
      advisory['packages'].each do |package|
        check_yum_package(adv, package)
      end

    end
  end

  # This URL posts CentOS errata for Spacewalk, by parsing the
  # CentOS-Announce archives.  If this ever stops being maintained, then
  # we would need to look at another source/using his scripts for ourselves.
  def get_centos_advisories
    uri = URI(CENTOS_ADV)
    Net::HTTP::Proxy(PROXY_ADDR, PROXY_PORT).start(uri.host, uri.port, :use_ssl => 1) do |http|
      return http.get(uri.path).body
    end
  end

  # Refresh and get a list of all RHEL advisories.  These are posted on RH's
  # website as cvrf files.
  def get_rhel_advisories
    # TODO: Refresh files.

    advisory_dir = REPORTS_DIR + RHEL_ADV_DIR
    advisories = []
    Find.find(advisory_dir) do |path|
      next unless File.file?(path)
      next unless /\.xml$/.match(path)
      advisories << path
    end

    return advisories
  end

  # Given a centos package version, parse out and return the major OS release
  # it is meant for.  If the version doesn't include the information needed
  # to figure that, return a 0.
  def centos_package_major_release (version)
    if m = /\.(el|centos|rhel)(\d)/i.match(version)
      return m[2].to_i
    else
      return 0
    end
  end

  # The centos advisory package includes an os_release field, but only one.
  # At the same time it can have fixes for multiple releases.  Parse out each
  # release to find the EL part of the R_M filename, and return a list of all
  # relevant versions.
  def used_release? (packages, valid_releases = [5, 6, 7])
    packages.each do |package|
      m = /^(.+)-([^-]+)-([^-]+)\.(\w+)\.rpm$/.match(package)
      package_name = m[1]
      package_version = m[2]
      package_subver = m[3]
      package_architecture = m[4]

      # Get the major release from the package name and see if it matches one
      # of the versions we care about.  If we can't get the major release,
      # assume that it matches.
      release = centos_package_major_release(package_subver)
      return true if release == 0
      return true if valid_releases.include?(release)
    end

    return false
  end

  # Given a cvrf file, attempt to parse it and return the data.
  def parse_cvrf (fname)
    @doc = Nokogiri::XML(File.read(fname))
    @doc.remove_namespaces!

    # Get basic simple text about the advisory.
    advisory = {}
    advisory['description'] = @doc.at_xpath('//DocumentTitle').content
    advisory['name'] = @doc.at_xpath('//DocumentTracking/Identification/ID').content
    advisory['severity'] = @doc.at_xpath('//AggregateSeverity').content
    advisory['issue_date'] = @doc.at_xpath('//DocumentTracking/InitialReleaseDate').content
    advisory['kind'] = @doc.at_xpath('//DocumentType').content
    advisory['os_family'] = 'RHEL'

    # There can be multiple references and synopses, but they'll usually be the
    # exact same item.  For our purposes we just want to pick the first.
    advisory['reference'] = @doc.xpath("//DocumentReferences/Reference[@Type='Self']/URL").first.content
    advisory['synopsis'] = @doc.xpath("//Vulnerability/Notes/Note[@Title='Vulnerability Description']").first.content

    # Each advisory may cover one or more CVEs.
    # TODO: Field for CVEs
    advisory['cves'] = []
    @doc.xpath("//Vulnerability/CVE").each do |cve|
      advisory['cves'] << cve.content
    end

    # Lastly, find and parse out all of the packages that will fix this advisory.
    advisory['packages'] = []
    @doc.xpath('//ProductStatuses').each do |product|
      next unless product['Type'] = 'Fixed'
      product.xpath('//ProductStatuses/Status/ProductID').each do |package|
        formatted = parse_rhel_package(package.content)
        next if formatted == ''
        advisory['packages'] << formatted
      end
    end

    return advisory
  end

  private

  # Take a hostname, os release, and the time a yaml report was generated.
  # Use these to create or update a server record, along with clearing all
  # packages for that record so that new packages may be updated.
  def save_server (hostname, os_release, last_checkin)
    server = Server.find_or_create_by(hostname: hostname)
    server.os_release = os_release
    server.last_checkin = last_checkin

    server.servers_to_packages.clear
    server.save

    log.info("Servers: Added/updated #{server.hostname}")
    return server
  end

  # Take an advisory record from the centos errata, parse it out, and then add
  # to the database.
  def add_centos_advisory (advisory)

    # Advisory data shouldn't change, so if the advisory already exists we can
    # just return the existing record.
    if Advisory.exists?(name: advisory.name)
      log.info("CentOS Advisories: #{advisory.name} already exists")
      return Advisory.find_by(name: advisory.name)
    end

    # Many advisories don't have a set severity, so give a default.
    if advisory.attributes['severity']
      severity = advisory.attributes['severity']
    else
      severity = 'Unknown'
    end

    # Get all the package names at once to save as details.  We're going to
    # go through them again later, but do this once now to save them with
    # the normal record.  This field will only be to keep the information
    # with the record for manual debugging.
    packages = []
    advisory.elements.each('packages') do |adv_package|
      packages.push(adv_package.text)
    end

    attributes = advisory.attributes
    adv = Advisory.find_or_create_by(name: advisory.name,
                                     description: attributes['description'],
                                     issue_date: attributes['issue_date'],
                                     references: attributes['references'],
                                     kind: attributes['type'],
                                     synopsis: attributes['synopsis'],
                                     severity: severity,
                                     os_family: 'centos',
                                     fix_versions: packages.join("\n"))
    log.info("CentOS Advisories: Created #{advisory.name}")
    return adv
  end

  # Take advisory data from the RHEL cvrf advisories and then add it to the
  # database.
  def add_rhel_advisory (advisory)

    # Advisory data shouldn't change, so if the advisory already exists we can
    # just return the existing record.
    if Advisory.exists?(name: advisory['name'])
      log.info("RHEL Advisories: #{advisory['name']} already exists")
      return Advisory.find_by(name: advisory['name'])
    end

    adv = Advisory.find_or_create_by(name: advisory['name'],
                                     description: advisory['description'],
                                     issue_date: advisory['issue_date'],
                                     references: advisory['reference'],
                                     kind: advisory['kind'],
                                     synopsis: advisory['synopsis'],
                                     severity: advisory['severity'],
                                     os_family: advisory['os_family'],
                                     fix_versions: advisory['packages'].join("\n"))
    log.info("RHEL Advisories: Created #{advisory['name']}")
    return adv
  end

  # Take a single package name that has a yum advisory filed against it, then
  # parse out that name and find any packages with that name.  Check to see
  # which ones are before the patched version and mark any of those packages
  # as falling under the advisory.
  def check_yum_package (adv, advisory_package)
    m = /^(.+)-([^-]+)-([^-]+)\.(\w+)\.rpm$/.match(advisory_package)
    package_name = m[1]
    package_version = m[2]
    package_subver = m[3]
    package_architecture = m[4]
    return nil if package_architecture == 'src'

    advisory_ver = RPM::Version.new(package_version + '-' + package_subver)
    Package.where(name: package_name, arch: package_architecture,
                  provider: 'yum').find_each do |package|

      # Skip this package unless it's for the same major release as the
      # advisory package.
      package_release = centos_package_major_release(package.version)
      if package_release
        next unless used_release?([advisory_package], [package_release])
      end

      # And finally check to see if the package is older than the patched
      # version from the advisory, associating them if not.
      check_ver = RPM::Version.new(package.version)
      if (advisory_ver.newer?(check_ver))
        adv.advisories_to_packages.create(package_id: package.id)
      end
    end
  end

  # Maintain the ruby advisory database checkout by pulling fresh content.
  # If it does not yet exist, do an initial clone.
  def maintain_ruby_advisory_git
    checkout_dir = REPORTS_DIR + RUBY_ADV_DIR
    if (Dir.exist?(checkout_dir))
      git = Git.open(checkout_dir)
      git.pull
    else
      git = Git.clone(RUBY_ADV_GIT, RUBY_ADV_DIR, :path => REPORTS_DIR)
    end
  end

  # The advisory puts package names with the type (server, workstation, etc)
  # separated from the package name and version by a :.  Split off that first
  # part and just return the package itself.
  def parse_rhel_package (package)
    if m = /^([^:]+):(.+)/.match(package)
      type = m[1]
      if /^\dServer/.match(type)
        package = m[2]
      else
        package = ''
      end
    end
    return package
  end

  def log
    if @logger.nil?
      @logger = Logger.new(LOGFILE, shift_age = 'monthly')
      @logger.level = LOGLEVEL
    end
    @logger
  end

end
