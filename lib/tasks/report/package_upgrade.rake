namespace :report do
  desc 'Print out helper files for an mcollective package upgrade'
  task package_upgrade: :environment do
    package_search = ENV['PACKAGE'] || ''
    week = ENV['WEEK']

    # If no week is given, calculate the current week on a set of 1..4.
    unless week
      week_of_year = Time.new.strftime("%V").to_i
      week = week_of_year.modulo(4) + 1
    end

    # Get the report data structure.  We'll build this into an output string
    # that we'll either print to stdout or email.
    report = Report.new.create_upgrade_files(week, package_search)
  end
end
