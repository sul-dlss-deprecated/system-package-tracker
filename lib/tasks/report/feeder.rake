namespace :report do
  desc 'Create yaml report on vulnerabilities per server'
  task :feeder, [:output_type] => :environment do |_t, args|
    hostname = ENV['SEARCH_HOST'] || ''
    package_search = ENV['PACKAGE'] || ''

    # Get the report data structure.  We'll build this into an output string
    # that we'll either print to stdout or email.
    report = Report.new.advisories(hostname, package_search)

    puts report.to_yaml
    #puts report.to_json
    #host = report['xtf-prod.stanford.edu']
    #puts host.to_yaml
  end
end
