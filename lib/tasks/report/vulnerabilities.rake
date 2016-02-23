namespace :report do
  desc 'Report on total vulnerabilities per server'
  task vulnerabilities: :environment do
    report = Report.new.advisories()

    # Iterate through the report to find unique vulnerabilties and vulnerable
    # packages for a summary.  Having the summary up top means we need to do
    # this before the main report, so we have to iterate through the
    # vulnerabiltiies twice.  That sucks, but the status makes more sense up
    # top.
    vulnerable_packages = {}
    vulnerabilities = {}
    report.keys.sort.each do |hostname|
      report[hostname].keys.sort.each do |package|
        report[hostname][package].keys.sort.each do |version|
          unique_pkg = package + '-' + version
          vulnerable_packages[unique_pkg] = 1
          report[hostname][package][version].each do |advisory|
            vulnerabilities[advisory['name']] = 1
          end
        end
      end
    end

    # Print that summary.
    total_systems = Server.count
    affected_systems = report.keys.count
    printf("%-32s: %d/%d\n", 'Hosts with vulnerable packages',
      affected_systems, total_systems)
    printf("%-32s: %d\n", 'Vulnerable packages',
      vulnerable_packages.keys.count)
    printf("%-32s: %d\n", 'Total vulnerabilities', vulnerabilities.keys.count)
    puts

    # Now do the actual report of each server and its advisories.
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
