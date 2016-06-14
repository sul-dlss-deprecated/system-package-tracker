namespace :report do
  desc 'Print out helper files for an mcollective package upgrade'
  task package_upgrade: :environment do
    package_search = ENV['PACKAGE'] || ''

    # Build the reports for each week.
    (1..4).each do |week|
      Report.new.create_upgrade_files(week, package_search)
    end
  end
end
