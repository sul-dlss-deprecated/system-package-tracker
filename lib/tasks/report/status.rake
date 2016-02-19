namespace :report do
  desc 'Report on overall packaging status'
  task status: :environment do

    report = Report.new.advisories()

    total_systems = Server.count
    affected_systems = report.keys.count

    # Iterate through the report to find unique vulnerabilties and vulnerable
    # packages.
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

    printf("%-32s: %d/%d\n", 'Hosts with vulnerable packages',
      affected_systems, total_systems)
    printf("%-32s: %d\n", 'Vulnerable packages',
      vulnerable_packages.keys.count)
    printf("%-32s: %d\n", 'Total vulnerabilities', vulnerabilities.keys.count)

  end
end
