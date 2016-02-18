namespace :report do
  desc 'Report on packages per server'
  task packages: :environment do
    report = Report.new.installed_packages()

    report.keys.sort.each do |hostname|
      puts hostname

      report[hostname].keys.sort.each do |type|
        puts "\t" + type
        report[hostname][type].keys.sort.each do |package|
          versions = report[hostname][type][package].join(', ')
          puts "\t\t#{package} (#{versions})"
        end
      end
    end
  end
end
