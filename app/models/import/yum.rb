class Import
  # Loading Yum-based advisory data, both for CentOS sources and for RHEL
  # sources.
  class Yum
    require 'net/http'
    require 'nokogiri'
    require 'rexml/document'
    require 'find'
    require 'yaml'
    require 'rpm'
    require 'logger'
    require 'activerecord-import'
    require 'activerecord-import/base'
    ActiveRecord::Import.require_adapter('pg')

    LOGFILE       = 'log/import.log'.freeze
    LOGLEVEL      = Logger::INFO

    PROXY_ADDR    = 'swp.stanford.edu'.freeze
    PROXY_PORT    = 80

    CENTOS_ADV    = 'https://raw.githubusercontent.com/stevemeier/cefs/master/errata.latest.xml'.freeze

    REPORTS_DIR = '/home/reporting/'.freeze
    RUBY_ADV_DIR = 'ruby-advisory-db'.freeze
    RHEL_ADV_DIR = 'rhel-cvrf'.freeze

    def centos_advisories
      # Parse the data and look up.  The file is formatted with every advisory
      # under <opt>.
      xml_data = load_centos_advisories
      doc = REXML::Document.new(xml_data)
      doc.elements.each('opt/*') do |advisory|
        next if advisory.name == 'meta'

        # Any advisory lines that end in -X\d\d\d are all for Xen4CentOS, which
        # we don't run and will give false flags.
        next if /--X\d{3}$/ =~ advisory.name

        # This contains bugfix and feature improvements, but we only care about
        # the actual security advisories.
        next unless advisory.attributes['type'] == 'Security Advisory'

        # Skip this record if it doesn't include a release we care about.
        packages = []
        advisory.elements.each('packages') do |adv_package|
          packages.push(adv_package.text)
        end
        unless used_release?(packages)
          log.info("CentOS Advisories: Skipping #{advisory.name}, not for any " \
            'OS releases we use')
          next
        end

        # Add the advisory and then link to any affected packages.
        adv = add_centos_advisory(advisory)
        packages.each do |package|
          check_yum_package(adv, package)
        end
      end
    end

    # Search the advisory directory, skipping advisories for gems we don't
    # have installed, and then checking those that we do have installed for
    # matching versions.
    def rhel_advisories
      advisories = load_rhel_advisories
      advisories.sort.each do |fname|
        advisory = parse_cvrf(fname)
        next if advisory.empty?

        # Log a note about any advisories that we could not get packages from.
        if advisory['packages'].nil? || advisory['packages'].empty?
          log.info("RHEL Advisories: No packages listed in #{fname}")
          next
        end

        # Skip this record if it doesn't include a release we care about.
        unless used_release?(advisory['packages'])
          log.info("RHEL Advisories: Skipping #{advisory['name']}, not for " \
            'any OS releases we use')
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
    def load_centos_advisories
      uri = URI(CENTOS_ADV)
      if PROXY_ADDR == ''
        Net::HTTP.start(uri.host, uri.port, use_ssl: 1) do |http|
          return http.get(uri.path).body
        end
      else
        Net::HTTP::Proxy(PROXY_ADDR, PROXY_PORT).start(uri.host, uri.port,
                                                       use_ssl: 1) do |http|
          return http.get(uri.path).body
        end
      end
    end

    # Refresh and get a list of all RHEL advisories.  These are posted on RH's
    # website as cvrf files.
    def load_rhel_advisories
      # TODO: Refresh files.

      advisory_dir = REPORTS_DIR + RHEL_ADV_DIR
      advisories = []
      Find.find(advisory_dir) do |path|
        next unless File.file?(path)
        next unless /\.xml$/ =~ path
        advisories << path
      end
    end

    # Given a centos package version, parse out and return the major OS release
    # it is meant for.  If the version doesn't include the information needed
    # to figure that, return a 0.
    def centos_package_major_release(version)
      m = /\.(el|centos|rhel)(\d)/i.match(version)
      return 0 if m.nil?
      m[2].to_i
    end

    # The centos advisory package includes an os_release field, but only one.
    # At the same time it can have fixes for multiple releases.  Parse out each
    # release to find the EL part of the R_M filename, and return a list of all
    # relevant versions.
    def used_release?(packages, valid_releases = [5, 6, 7])
      packages.each do |package|
        m = /^(.+)-([^-]+)-([^-]+)\.(\w+)\.rpm$/.match(package)
        return true if m.nil?
        package_subver = m[3]

        # Get the major release from the package name and see if it matches one
        # of the versions we care about.  If we can't get the major release,
        # assume that it matches.
        release = centos_package_major_release(package_subver)
        return true if release == 0
        return true if valid_releases.include?(release)
      end

      false
    end

    # Given a cvrf file, attempt to parse it and return the data.
    def parse_cvrf(fname)
      @doc = Nokogiri::XML(File.read(fname))
      @doc.remove_namespaces!

      # Get basic simple text about the advisory.
      advisory = {}
      begin
        advisory['description'] = @doc.at_xpath('//DocumentTitle').content
        advisory['name'] =
          @doc.at_xpath('//DocumentTracking/Identification/ID').content
        advisory['severity'] = @doc.at_xpath('//AggregateSeverity').content
        advisory['issue_date'] =
          @doc.at_xpath('//DocumentTracking/InitialReleaseDate').content
        advisory['kind'] = @doc.at_xpath('//DocumentType').content
        advisory['os_family'] = 'rhel'

        # There can be multiple references and synopses, but they'll usually be
        # the exact same item.  For our purposes we just want to pick the first.
        path = "//DocumentReferences/Reference[@Type='Self']/URL"
        advisory['reference'] = @doc.xpath(path).first.content
        path = "//Vulnerability/Notes/Note[@Title='Vulnerability Description']"
        vulnerability = @doc.xpath(path)
        if vulnerability.first.nil?
          advisory['synopsis'] = ''
        else
          advisory['synopsis'] = vulnerability.first.content
        end

        # Each advisory may cover one or more CVEs.
        # TODO: Field for CVEs
        advisory['cves'] = []
        @doc.xpath('//Vulnerability/CVE').each do |cve|
          advisory['cves'] << cve.content
        end

        # Lastly, find and parse out all of the packages that will fix this
        # advisory.  Expand any source packages into all the archs we use.
        packages = []
        @doc.xpath('//ProductTree/Branch[@Type="Product Version"]').each do |pv|
          pv.xpath('//ProductTree/Branch/FullProductName').each do |p|
            expand_rhel_src(p.content).each do |package|
              packages << package
            end
          end
        end
        advisory['packages'] = packages.uniq
      rescue NoMethodError
        log.info("RHEL Advisories: could not parse #{fname}")
      end

      advisory
    end

    private

    # Take an advisory record from the centos errata, parse it out, and then add
    # to the database.
    def add_centos_advisory(advisory)
      # Advisory data shouldn't change, so if the advisory already exists we can
      # just return the existing record.
      if Advisory.exists?(name: advisory.name)
        log.info("CentOS Advisories: #{advisory.name} already exists")
        return Advisory.find_by(name: advisory.name)
      end

      # Many advisories don't have a set severity, so give a default.
      severity = if advisory.attributes['severity']
                   advisory.attributes['severity']
                 else
                   'Unknown'
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
      adv
    end

    # Take advisory data from the RHEL cvrf advisories and then add it to the
    # database.
    def add_rhel_advisory(advisory)
      # Advisory data shouldn't change, so if the advisory already exists we can
      # just return the existing record.
      if Advisory.exists?(name: advisory['name'])
        log.info("RHEL Advisories: #{advisory['name']} already exists")
        return Advisory.find_by(name: advisory['name'])
      end

      fixes = advisory['packages'].join("\n")
      adv = Advisory.find_or_create_by(name: advisory['name'],
                                       description: advisory['description'],
                                       issue_date: advisory['issue_date'],
                                       references: advisory['reference'],
                                       kind: advisory['kind'],
                                       synopsis: advisory['synopsis'],
                                       severity: advisory['severity'],
                                       os_family: advisory['os_family'],
                                       fix_versions: fixes)
      log.info("RHEL Advisories: Created #{advisory['name']}")
      adv
    end

    # Take a single package name that has a yum advisory filed against it, then
    # parse out that name and find any packages with that name.  Check to see
    # which ones are before the patched version and mark any of those packages
    # as falling under the advisory.
    def check_yum_package(adv, advisory_package)
      m = /^(.+)-([^-]+)-([^-]+)\.(\w+)\.rpm$/.match(advisory_package)
      package_name = m[1]
      package_version = m[2]
      package_subver = m[3]
      package_architecture = m[4]
      return nil if package_architecture == 'src'

      os_family = adv.os_family
      advisory_ver = RPM::Version.new(package_version + '-' + package_subver)
      Package.where(name: package_name, arch: package_architecture,
                    provider: 'yum', os_family: os_family).find_each do |p|
        # Skip this package unless it's for the same major release as the
        # advisory package.
        package_release = centos_package_major_release(p.version)
        next if package_release && !used_release?([advisory_package],
                                                  [package_release])

        # And finally check to see if the package is older than the patched
        # version from the advisory, associating them if not.
        check_ver = RPM::Version.new(p.version)
        adv.advisories_to_packages.create(package_id: p.id) \
          if advisory_ver.newer?(check_ver)
      end
    end

    # The advisory puts package names with the type (server, workstation, etc)
    # separated from the package name and version by a :.  Split off that first
    # part and just return the package itself.
    def parse_rhel_package(package)
      m = /^([^:]+):(.+)/.match(package)
      unless m.nil?
        type = m[1]
        return m[2] if /^\dServer/ =~ type
        return ''
      end
      package
    end

    # The RHEL cvrf files seem to use the .src.rpm in some cases where they mean
    # that an update applies to all of the architectures for this update.  See
    # if the given RPM is for a source package and if so, replace with the
    # x86_64 and i386 versions.
    def expand_rhel_src(package)
      m = /^(.+)\.src\.rpm$/.match(package)
      return [package] if m.nil?

      [m[1] + '.x86_64.rpm', m[1] + '.i386.rpm']
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
end
