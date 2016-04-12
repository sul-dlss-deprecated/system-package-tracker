# Loading Yum-based advisory data, both for CentOS sources and for RHEL
# sources.
class Import
  class Packages
    class Yum
      class RHEL < Import::Packages::Yum
        require 'nokogiri'
        require 'find'
        require 'yaml'
        require 'logger'
        require 'activerecord-import'
        require 'activerecord-import/base'
        ActiveRecord::Import.require_adapter('pg')

        LOGFILE       = 'log/import.log'.freeze
        LOGLEVEL      = Logger::INFO

        REPORTS_DIR = '/home/reporting/'.freeze
        RHEL_ADV_DIR = 'rhel-cvrf'.freeze

        # Search the advisory directory, skipping advisories for gems we don't
        # have installed, and then checking those that we do have installed for
        # matching versions.
        def import_advisories
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
            adv = add_record(advisory)
            advisory['packages'].each do |package|
              check_yum_package(adv, package)
            end
          end
        end

        def import_source
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

        # Take advisory data from the RHEL cvrf advisories and then add it to the
        # database.
        def add_record(advisory)
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
  end
end
