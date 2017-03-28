# Loading Yum-based advisory data, both for CentOS sources and for RHEL
# sources.
class Import
  class Packages
    class Yum
      class RHEL < Import::Packages::Yum
        require 'nokogiri'
        require 'net/http'
        require 'find'
        require 'yaml'
        require 'logger'

        LOGFILE       = 'log/import.log'.freeze
        LOGLEVEL      = Logger::INFO

        PROXY_ADDR    = 'swp.stanford.edu'.freeze
        PROXY_PORT    = 80

        REPORTS_DIR = '/home/reporting/'.freeze
        RHEL_ADV_DIR = 'rhel-cvrf'.freeze

        OVAL_LOCAL = '/home/reporting/com.redhat.rhsa-all.xml'.freeze
        OVAL_REMOTE_HOST = 'https://www.redhat.com'.freeze
        OVAL_REMOTE_PATH = '/security/data/oval/com.redhat.rhsa-all.xml.bz2'.freeze

        # Search the advisory directory, skipping advisories for gems we don't
        # have installed, and then checking those that we do have installed for
        # matching versions.
        def import_advisories
          advisories = parse_oval(OVAL_LOCAL)
          advisories.each do |advisory|

            # Log a note about any advisories that we could not get packages from.
            if advisory['packages'].nil? || advisory['packages'].empty?
              log.info('RHEL Advisories: No packages listed in ' \
                "#{advisory['name']}")
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

        # Download the RHEL OVAL file and unbzip it for later use.
        def import_source
          tmpfile = OVAL_LOCAL + '.bz2'
          content = ''
          uri = URI.parse(OVAL_REMOTE_HOST + OVAL_REMOTE_PATH)

          if PROXY_ADDR == ''
            http = Net::HTTP.new(uri.host, uri.port)
          else
            http = Net::HTTP::Proxy(PROXY_ADDR, PROXY_PORT).new(uri.host, uri.port)
          end
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          content = http.get(uri.path).body

          open(tmpfile, 'wb') do |file|
            file.write(content)
          end
          system('bunzip2', '--force', tmpfile)
        end

        # Parse the RHEL oval XML file containing advisory information.
        def parse_oval(fname)
          doc = Nokogiri::XML(File.read(fname))
          doc.remove_namespaces!

          # Get basic simple text about the advisory.
          advisories = []
          begin
            doc.xpath('/oval_definitions/definitions/definition').each do |d|
              advisory = {}
              advisory['description'] = d.at_xpath('metadata/description').content
              advisory['name'] = d.at_xpath('metadata/title').content
              advisory['title'] = advisory['name']
              advisory['issue_date'] = d.at_xpath('metadata/advisory/issued')['date']
              advisory['severity'] = d.at_xpath('metadata/advisory/severity').content
              advisory['kind'] = 'Security Advisory'
              advisory['os_family'] = 'rhel'
              advisory['cve'] = d.at_xpath('metadata/advisory/cve').content

              advisory['upstream_id'] = ''
              m = /^(\S+):/.match(advisory['name'])
              advisory['upstream_id'] = m[1] unless m.nil?

              # Packages are saved as criteria for matching.  We'll parse them out to
              # find the actual names/versions.
              packages = []
              d.xpath('criteria//criterion').each do |c|
                m = /^(\S+) is earlier than (.+)$/.match(c['comment'])
                next if m.nil?
                packages << m[1] + '-' + m[2] + '.x86_64.rpm'
                packages << m[1] + '-' + m[2] + '.i386.rpm'
              end
              advisory['packages'] = packages

              # And gather the references, which are split between fields.
              references = []
              d.xpath('metadata/reference').each do |r|
                references << r['ref_url']
              end
              advisory['references'] = references.join("\n")

              advisories << advisory
            end
          rescue NoMethodError
            log.info("RHEL Advisories: could not parse #{fname}")
          end

          advisories
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
                                           title: advisory['title'],
                                           description: advisory['description'],
                                           issue_date: advisory['issue_date'],
                                           references: advisory['reference'],
                                           kind: advisory['kind'],
                                           severity: advisory['severity'],
                                           os_family: advisory['os_family'],
                                           cve: advisory['cve'],
                                           upstream_id: advisory['upstream_id'],
                                           fix_versions: fixes)
          log.info("RHEL Advisories: Created #{advisory['name']}")
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
