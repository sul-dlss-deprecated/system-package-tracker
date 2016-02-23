class Import

  # TODO: Add logging for all of our changes.

  require 'net/http'
  require 'rexml/document'
  require 'yaml'
  require 'rubygems'
  require 'rpm'

  SERVER_FILES  = '/var/lib/package-reports/*.yaml'
  ADV_DIRECTORY = '/var/lib/ruby-advisory-db/gems'

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
      next unless used_release?(packages)

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

    Dir.glob(SERVER_FILES).each do |yaml_file|
      server_yaml = YAML.load(File.open(yaml_file))

      # Get or create a host record.
      hostname = server_yaml['system']['hostname']
      server = save_server(hostname, server_yaml['system']['release'],
                           server_yaml['system']['lastrun'])

      # Add any missing packages to the database and then associating them
      # with the server.  Packages may be marked either installed or pending
      # (for upgrades not installed).  There can be multiple versions of a
      # package on a system, for gemfiles.
      package_types.each do |type|
        status_types.each do |status|
          next unless server_yaml[type].key?(status)
          server_yaml[type][status].each_key do |pkg|
            arch = server_yaml[type][status][pkg]['arch'] || 'none'
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

  def ruby_advisories

    # TODO: Actually run a git update on the advisory repo.

    # Search the advisory directory, skipping advisories for gems we don't
    # have installed, and then checking those that we do have installed for
    # matching versions.
    Dir.foreach(ADV_DIRECTORY) do |gem|
      next if gem == '.' || gem == '..'
      packages = Package.where(name: gem, provider: 'gem')
      next unless packages.count > 0

      gemdir = "#{ADV_DIRECTORY}/#{gem}/"
      Dir.glob(gemdir + '*.yml') do |adv_file|
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

        adv = Advisory.find_or_create_by(name: name,
                                         description: description,
                                         issue_date: issue_date,
                                         references: references,
                                         kind: kind,
                                         synopsis: synopsis,
                                         severity: severity,
                                         os_family: os_family,
                                         fix_versions: fix_versions)

        # Check each package with this name to see if it is affected by the
        # advisory.  This uses gem formatted requirement strings, so use that
        # to parse if the packages match.
        packages.each do |package|
          matched = 0
          advisory['patched_versions'].each do |version|
            pv = Gem::Version.new(package.version)
            if Gem::Requirement.new(version.split(',')).satisfied_by?(pv)
              matched = 1
              break
            end
          end
          unless matched == 1
            adv.advisories_to_packages.create(package_id: package.id)
          end
        end
      end
    end
  end

  # This URL posts CentOS errata for Spacewalk, by parsing the
  # CentOS-Announce archives.  If this ever stops being maintained, then
  # we would need to look at another source/using his scripts for ourselves.
  def get_centos_advisories
    # TODO: We need to use the proxy here.  wget is using, but not us.
    xml_data = File.new('/tmp/errata.latest.xml')
    return xml_data.read
#    url = 'http://cefs.steve-meier.de/errata.latest.xml'
#    xml_data = Net::HTTP.get_response(URI.parse(url)).body
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

    return server
  end

  # Take an advisory record from the centos errata, parse it out, and then add
  # to the database.
  def add_centos_advisory (advisory)

    # Advisory data shouldn't change, so if the advisory already exists we can
    # just return the existing record.
    if Advisory.exists?(name: advisory.name)
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

end
