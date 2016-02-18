namespace :report do
  desc 'Report on total vulnerabilities per server'
  task vulnerabilities: :environment do
    report = {}
    Server.all.order('hostname').each do |server|

      packages = {}
      server.installed_packages.order('name').each do |package|
        advisories = []
        package.advisories.order('name').uniq.each do |advisory|

          # Filter out fixed packages of everything but this package.  This
          # lets us see the version that has the fix.
          fixed = []
          advisory.fix_versions.split("\n").each do |fixed_package|
            m = /^(.+)-([^-]+)-([^-]+)\.(\w+)\.rpm$/.match(fixed_package)
            next unless m[1] == package.name
            next unless m[4] == package.arch
            fixed.push(m[2] + '-' + m[3])
          end

          # Convert to a hash to drop into our results structure.
          advisory_report = advisory.as_json
          advisory_report['fix_versions_filtered'] = fixed.join(" ")
          advisories << advisory_report
        end

        # Now add any advisories to the record for this package/version.
        unless advisories.empty?
          unless packages.key?(package.name)
            packages[package.name] = {}
          end
          packages[package.name][package.version] = advisories
        end
      end

      # And if there were any packages, add them to the server.
      unless packages.empty?
        report[server.hostname] = packages
      end

    end

    report.keys.sort.each do |hostname|
      puts hostname

      report[hostname].keys.sort.each do |package|
        report[hostname][package].keys.sort.each do |version|
          puts "\t#{package} #{version}"
          report[hostname][package][version].each do |advisory|
            puts "\t\t" + advisory['name'] + ' ' + advisory['fix_versions_filtered']
          end
        end
      end
    end

  end
end
