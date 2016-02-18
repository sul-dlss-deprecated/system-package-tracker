namespace :report do
  desc 'Report on total vulnerabilities per server'
  task vulnerabilities: :environment do
    report = Report.new.advisories()
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
