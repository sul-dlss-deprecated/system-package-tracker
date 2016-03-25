# Import the ruby gem advisory database, including advisories for the gems in
# actual use.
class Import::Gems
  require 'net/http'
  require 'git'
  require 'yaml'
  require 'rubygems'
  require 'logger'
  require 'activerecord-import'
  require 'activerecord-import/base'
  ActiveRecord::Import.require_adapter('pg')

  LOGFILE       = 'log/import.log'.freeze
  LOGLEVEL      = Logger::INFO

  PROXY_ADDR    = 'swp.stanford.edu'.freeze
  PROXY_PORT    = 80

  RUBY_ADV_GIT = 'https://github.com/rubysec/ruby-advisory-db.git'.freeze
  REPORTS_DIR = '/home/reporting/'.freeze
  RUBY_ADV_DIR = 'ruby-advisory-db'.freeze

  # Search the advisory directory, skipping advisories for gems we don't
  # have installed, and then checking those that we do have installed for
  # matching versions.
  def ruby_advisories
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
        advisory = YAML.load(File.open(adv_file))

        # The advisories pull both from CVEs and from OSVDB.  In some cases
        # the advisory will have both, but in most cases the name will be one
        # or the other.
        name = if advisory['cve'] && advisory['osvdb']
                 advisory['cve'] + '/' + advisory['osvdb'].to_s
               else
                 advisory['cve'] || advisory['osvdb']
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
        patched_versions << advisory['patched_versions'] \
          if advisory.key?('patched_versions')
        patched_versions << advisory['unaffected_versions'] \
          if advisory.key?('unaffected_versions')
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
              log.info("Ruby advisories: Skipping link of #{gem}/#{name} to " \
                "#{package.name} #{package.version}: patch satisfied by " \
                "#{version}")
              matched = 1
              break
            end
          end
          unless matched == 1
            log.info("Ruby advisories: Linked #{gem}/#{name} to " \
              "#{package.name} #{package.version}")
            adv.advisories_to_packages.create(package_id: package.id)
          end
        end
      end
    end
  end

  # Maintain the ruby advisory database checkout by pulling fresh content.
  # If it does not yet exist, do an initial clone.
  def update_source
    checkout_dir = REPORTS_DIR + RUBY_ADV_DIR
    if Dir.exist?(checkout_dir)
      git = Git.open(checkout_dir)
      git.pull
    else
      Git.clone(RUBY_ADV_GIT, RUBY_ADV_DIR, path: REPORTS_DIR)
    end
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
