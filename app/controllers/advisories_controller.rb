class AdvisoriesController < ApplicationController
  require 'net/http'
  require 'rexml/document'
  require 'yaml'

  url = 'http://cefs.steve-meier.de/errata.latest.xml'
  xml_data = Net::HTTP.get_response(URI.parse(url)).body

  doc = REXML::Document.new(xml_data)
  puts "Test"

  doc.elements.each('opt/*') { |advisory|

    # Skip the meta item, the one thing in the XML doc that's not an advisory.
    next if advisory.name == 'meta'

    # Many advisories don't have a set severity.
    if advisory.attributes['severity']
      severity = advisory.attributes['severity']
    else
      severity = 'Unknown'
    end

    # Create the advisory if it does not yet exist.
    adv = Advisory.find_or_create_by(name: advisory.name,
                                     description: advisory.attributes['description'],
                                     issue_date: advisory.attributes['issue_date'],
                                     references: advisory.attributes['references'],
                                     kind: advisory.attributes['type'],
                                     synopsis: advisory.attributes['synopsis'],
                                     severity: severity,
                                     os_family: 'centos')

    # Now link each advisory to any known packages.
    advisory.elements.each('packages') { |package|
      m = /^(.+)-([^-]+)-([^-]+)\.(\w+)\.rpm$/.match(package.text)
      package_name = m[1]
      package_version = m[2]
      package_subver = m[3]
      package_architecture = m[4]
      next if package_architecture == 'src'

      Package.where(name: package_name, arch: package_architecture, 
                    provider: 'yum').find_each do |package|

        # FIXME: Can't run the RPM gem on my laptop for lack of RPM libs.
        #advisory_ver = RPM::Version.new(package_version + '-' + package_subver)
        #if (advisory_ver.newer?(check_ver))
          adv.advisories_to_packages.create(package_id: package.id)
        #end
      end
    }
  }

end
