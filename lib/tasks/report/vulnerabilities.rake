namespace :report do
  desc 'Report on total vulnerabilities per server'
  task :vulnerabilities, [:output_type] => :environment do |t, args|
    output_type = args[:output_type] || 'stdout'

    # Get the report data structure.  We'll build this into an output string
    # that we'll either print to stdout or email.
    report = Report.new.advisories()
    output = ''

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
    output << sprintf("%-32s: %d/%d\n", 'Hosts with vulnerable packages',
      affected_systems, total_systems)
    output << sprintf("%-32s: %d\n", 'Vulnerable packages',
      vulnerable_packages.keys.count)
    output << sprintf("%-32s: %d\n", 'Total vulnerabilities',
      vulnerabilities.keys.count)
    output << "\n"

    # Now do the actual report of each server and its advisories.
    report.keys.sort.each do |hostname|
      output << hostname + "\n"

      report[hostname].keys.sort.each do |package|
        report[hostname][package].keys.sort.each do |version|
          output << "\t#{package} #{version}\n"
          report[hostname][package][version].each do |advisory|
            output << "\t\t" + advisory['name'] + ' ' + advisory['fix_versions_filtered'] + "\n"
          end
        end
      end
    end

    # Either print or email the report, depending on argument.
    if output_type == 'email'
      ReportMailer.advisory_email(output).deliver_now
    else
      print output
    end

  end
end
