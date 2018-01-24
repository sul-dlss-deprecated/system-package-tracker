# Report
namespace :report do
  desc 'Report on systems that need special looks and handling'
  task alerts: :environment do
    LAST_CHECKIN = 30.days.ago
    require 'csv'

    report = {}
    Server.where("last_checkin > ?", LAST_CHECKIN).find_each do |server|

      # Initialize all of the fields we care about, since few servers will have
      # all.
      report[server.hostname] = {}
      report[server.hostname]['kernel'] = ''
      report[server.hostname]['apache'] = ''
      report[server.hostname]['tomcat'] = ''
      report[server.hostname]['webauth'] = ''
      report[server.hostname]['shibboleth'] = ''

      server.installed_packages.each do |package|

        # For a kernel, we only care if it is at the latest version or not.
        if package.name == 'kernel'
          name = package.name
          pending = Package.includes(:pending_packages).find_by(packages: { name: name }, servers: { hostname: server.hostname })
          if pending.nil?
            report[server.hostname]['kernel'] = 'Latest'
          else
            report[server.hostname]['kernel'] = 'Needs update'
          end

        # For Apache do the same, with the added bit that this won't shot at
        # all unless apache is installed.
        elsif package.name == 'httpd'
          name = package.name
          pending = Package.includes(:pending_packages).find_by(packages: { name: name }, servers: { hostname: server.hostname })
          if pending.nil?
            report[server.hostname]['apache'] = 'Latest'
          else
            report[server.hostname]['apache'] = 'Needs update'
          end

        # For the rest, we only care whether or not the package is installed.
        elsif package.name == 'tomcat' || package.name == 'tomcat6'
          report[server.hostname]['tomcat'] = '*'
        elsif package.name == 'webauth'
          report[server.hostname]['webauth'] = '*'
        elsif package.name == 'shibboleth'
          report[server.hostname]['shibboleth'] = '*'
        end
      end
    end

    # Print out the header, then each sorted line, both as CSV.
    puts ['Hostname', 'Kernel', 'Apache', 'Tomcat', 'Webauth', 'Shibboleth'].to_csv
    report.keys.sort.each do |host|
      line = [host, report[host]['kernel'], report[host]['apache'],
              report[host]['tomcat'], report[host]['webauth'],
              report[host]['shibboleth']]
      puts line.to_csv
    end

  end
end
