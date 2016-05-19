# Loading Yum-based advisory data, both for CentOS sources and for RHEL
# sources.
class Import
  class Packages
    class Yum
      class Centos < Import::Packages::Yum
        require 'net/http'
        require 'rexml/document'
        require 'find'
        require 'yaml'
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

        def import_advisories
          # Parse the data and look up.  The file is formatted with every advisory
          # under <opt>.
          xml_data = update_source
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
            adv = add_record(advisory)
            packages.each do |package|
              check_yum_package(adv, package)
            end
          end
        end

        # This URL posts CentOS errata for Spacewalk, by parsing the
        # CentOS-Announce archives.  If this ever stops being maintained, then
        # we would need to look at another source/using his scripts for ourselves.
        def update_source
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

        private

        # Take an advisory record from the centos errata, parse it out, and then add
        # to the database.
        def add_record(advisory)
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

          # The CVE is only available inside the references URLs.
          m = /\/(CVE-\d+-\d+)/.match(advisory.attributes['references'])
          cve = ''
          cve = m[1] unless m.nil?

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
                                           title: attributes['synopsis'],
                                           description: '',
                                           issue_date: attributes['issue_date'],
                                           references: attributes['references'],
                                           kind: attributes['type'],
                                           severity: severity,
                                           os_family: 'centos',
                                           cve: cve,
                                           upstream_id: advisory.name,
                                           fix_versions: packages.join("\n"))
          log.info("CentOS Advisories: Created #{advisory.name}")
          adv
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
