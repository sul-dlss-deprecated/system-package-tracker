# Handle loading advisories into the database.  This is meant to look up the
# listings for open advisories, parse the document(s), save any new
# advisories, then associate with affected packages.
class AdvisoriesController < ApplicationController
  require 'net/http'
  require 'rexml/document'
  require 'yaml'

  # TODO: This currrently only uses a source for CentOS.  Look into using
  # either Gemnasium or https://github.com/rubysec/ruby-advisory-db for 
  # getting advisories on gems, then add a second function for that.

  def index

    # This URL posts CentOS errata for Spacewalk, by parsing the 
    # CentOS-Announce archives.  If this ever stops being maintained, then
    # we would need to look at another source/using his scripts for ourselves.    
    url = 'http://cefs.steve-meier.de/errata.latest.xml'
    xml_data = Net::HTTP.get_response(URI.parse(url)).body

    # Parse the data and look up.  The file is formatted with every advisory
    # under <opt>.
    doc = REXML::Document.new(xml_data)
    doc.elements.each('opt/*') { |advisory|

      # Skip the meta item, the one thing in the XML doc that's not an advisory.
      next if advisory.name == 'meta'

      # Many advisories don't have a set severity, so give a default.
      if advisory.attributes['severity']
        severity = advisory.attributes['severity']
      else
        severity = 'Unknown'
      end

      # Create the advisory in the database if it does not yet exist.
      adv = Advisory.find_or_create_by(name: advisory.name,
                                       description: advisory.attributes['description'],
                                       issue_date: advisory.attributes['issue_date'],
                                       references: advisory.attributes['references'],
                                       kind: advisory.attributes['type'],
                                       synopsis: advisory.attributes['synopsis'],
                                       severity: severity,
                                       os_family: 'centos')

      # Now link the advisory to any known packages.  We don't bother removing
      # old entries, since an advisory that affects version X should always
      # affect version X.  Each advisory can affect multiple packages.
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
          # Once that is either working or I'm doing dev on another box,
          # restore the commented-out parts.  Right now we just are flagging
          # every version of a package as having that advisory, to make sure
          # the general logic is sound.
          #
          # Match the package's version against the version in the advisory,
          # associating the package and advisory only if the advisory needs
          # a later version of the package than this.
          #require 'rpm'
          #check_ver = RPM::Version.new(package.version)
          #advisory_ver = RPM::Version.new(package_version + '-' + package_subver)
          #if (advisory_ver.newer?(check_ver))
            adv.advisories_to_packages.create(package_id: package.id)
          #end
        end
      }
    }
  end

end
