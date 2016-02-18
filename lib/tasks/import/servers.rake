namespace :import do
  desc 'Import package reports from our servers'
  task servers: :environment do
    Import.new.servers()
  end
end
