namespace :report do
  desc 'Print out helper files for an mcollective package upgrade'
  task package_upgrade: :environment do
    package_search = ENV['PACKAGE'] || ''

    # Get the report data structure.  We'll build this into an output string
    # that we'll either print to stdout or email.
    report = Report.new.create_upgrade_files(package_search)
  end
end
