namespace :report do
  desc 'Report on total vulnerabilities per server'
  task :vulnerabilities, [:output_type] => :environment do |_t, args|
    output_type = args[:output_type] || 'stdout'
    hostname = ENV['SEARCH_HOST'] || ''
    package_search = ENV['PACKAGE'] || ''

    # Get the report data structure.  We'll build this into an output string
    # that we'll either print to stdout or email.
    report = Report.new.advisories(hostname, package_search)
    output = ''

    # Iterate through the report to find unique vulnerabilties and vulnerable
    # packages for a summary.  Having the summary up top means we need to do
    # this before the main report, so we have to iterate through the
    # vulnerabiltiies twice.  That sucks, but the status makes more sense up
    # top.
    vulnerable_packages = {}
    vulnerabilities = {}
    vulnerabilities_total = 0
    high_vulnerabilities = {}
    report.keys.sort.each do |host|
      report[host].keys.sort.each do |package|
        report[host][package].keys.sort.each do |version|
          unique_pkg = package + '-' + version
          vulnerable_packages[unique_pkg] = 1
          report[host][package][version].each do |advisory|
            next if advisory['os_family'] == 'gem'
            vulnerabilities[advisory['name']] = 1
            severity = advisory['severity']
            vulnerabilities_total += 1
            high_vulnerabilities[advisory['name']] = 1 \
              if severity == 'Important' || severity == 'Critical'
          end
        end
      end
    end

    # Print that summary.
    total_systems = Server.count
    affected_systems = report.keys.count
    output << format("%-32s: %d/%d\n", 'Hosts with one or more vulnerable RPMs',
                     affected_systems, total_systems)
    output << format("%-32s: %d\n",
                     'Total number of installed RPMs with open CVEs',
                     vulnerabilities_total)
    output << format("%-32s: %d\n",
                     'Unique number of installed RPMs with open CVEs',
                     vulnerable_packages.keys.count)
    output << format("%-32s: %d\n",
                     'Total number of unique CVEs across all systems',
                     vulnerabilities.keys.count)
    output << format("%-32s: %d\n",
                     'Number of high-level unique CVEs across all systems',
                     high_vulnerabilities.keys.count)
    output << "\n"

    # Now do the actual report of each server and its advisories.
    report.keys.sort.each do |host|
      output << host + "\n"

      report[host].keys.sort.each do |package|
        report[host][package].keys.sort.each do |version|
          output << "\t#{package} #{version}\n"
          report[host][package][version].each do |advisory|
            output << "\t\t" + advisory['name'] + ' ' +
                      advisory['fix_versions_filtered'] + "\n"
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
