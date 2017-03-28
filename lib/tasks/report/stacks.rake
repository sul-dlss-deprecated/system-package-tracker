namespace :report do
  desc 'Report on stack status'
  task :stacks, [:name, :output_type] => :environment do |_t, args|
    stack = args[:name]
    output_type = args[:output_type] || 'stdout'

    # Temp filler while Tony does puppet integration.
    hosts = [stack]
    hosts.sort.each do |hostname|
      report = Report.new.advisories(hostname, 'kernel')

      report.keys.sort.each do |host|
        report[host].keys.sort.each do |package|
          report[host][package].keys.sort.each do |version|
            unique_pkg = package + '-' + version
            output << format("%s\n", unique_pkg)
            report[host][package][version].each do |advisory|
              output << format("%s %s\n", advisory['name'],
                               advisory['severity'])
            end
          end
        end
      end
    end

    # Either print or email the report, depending on argument.
    if output_type == 'email'
      #ReportMailer.advisory_email(output).deliver_now
    else
      print output
    end
  end
end
