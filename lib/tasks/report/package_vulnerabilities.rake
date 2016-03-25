namespace :report do
  desc 'Report on vulnerabilities per package'
  task :package_vulnerabilities, [:output_type] => :environment do |_t, args|
    output_type = args[:output_type] || 'stdout'
    package_search = ENV['PACKAGE'] || ''

    # Get the report data structure.  We'll build this into an output string
    # that we'll either print to stdout or email.
    report = Report.new.advisories_by_package(package_search)
    output = ''

    # Now do the actual report of each server and its advisories.
    report.keys.sort.each do |name|
      report[name].keys.sort.each do |version|
        report[name][version].keys.sort.each do |arch|
          report[name][version][arch].keys.sort.each do |provider|
            advisories = report[name][version][arch][provider]['advisories']
            output << format("%s %s-%s (%s) (%s)\n", name, version, arch,
                             provider, advisories)
            report[name][version][arch][provider]['servers'].sort.each do |s|
              output << format("\t%s\n", s)
            end
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
