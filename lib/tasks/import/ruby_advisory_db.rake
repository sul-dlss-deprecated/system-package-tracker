namespace :import do
  desc 'Import gem advisories from the ruby advisory database'
  task ruby_advisory_db: :environment do
    adv_directory = '/var/lib/ruby-advisory-db/gems'

    # TODO: Actually run a git update on the advisory repo.

    # Search the advisory directory, skipping advisories for gems we don't
    # have installed, and then checking those that we do have installed for
    # matching versions.
    Dir.foreach(adv_directory) do |gem|
      installed = Package.where(name: gem, provider: 'gem')
      next unless installed.count > 0

      gemdir = "#{adv_directory}/#{gem}/"
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

        # Unaffected versions are equivalent to patched versions as far as we care.
        patched_versions = []
        if advisory.key?('patched_versions')
          patched_versions << advisory['patched_versions']
        end
        if advisory.key?('unaffected_versions')
          patched_versions << advisory['unaffected_versions']
        end
        next if patched_versions.count == 0
        fix_versions = patched_versions.join("\n")

        puts "Advisory for #{gem}, #{name}: #{synopsis}"
#        puts fix_versions
#        adv = Advisory.find_or_create_by(name: name,
#                                         description: description,
#                                         issue_date: issue_date,
#                                         references: references,
#                                         kind: kind,
#                                         synopsis: synopsis,
#                                         severity: severity,
#                                         os_family: os_family,
#                                         fix_versions: fix_versions)

        # Check each installed package with this name to see if it is
        # affected by the advisory.  This uses gem formatted requirement
        # strings, so use that to parse if the packages match.
        installed.each do |package|
          advisory['patched_versions'].each do |version|
            pv = Gem::Version.new(package.version)
            unless Gem::Requirement.new(version.split(',')).satisfied_by?(pv)
              # TODO: Add the association.
              puts "*** Advisory for #{package.version}"
              break
            end
          end
        end

      end
    end

  end
end
