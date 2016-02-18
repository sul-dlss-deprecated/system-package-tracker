# Handle loading advisories into the database.  This is meant to look up the
# listings for open advisories, parse the document(s), save any new
# advisories, then associate with affected packages.
class AdvisoriesController < ApplicationController
  require 'net/http'
  require 'rexml/document'
  require 'yaml'
  require 'rubygems'
  require 'rpm'

  # TODO: This currrently only uses a source for CentOS.  Look into using
  # either Gemnasium or https://github.com/rubysec/ruby-advisory-db for
  # getting advisories on gems, then add a second function for that.

  # This URL posts CentOS errata for Spacewalk, by parsing the
  # CentOS-Announce archives.  If this ever stops being maintained, then
  # we would need to look at another source/using his scripts for ourselves.
  def get_centos_advisories
    url = 'http://cefs.steve-meier.de/errata.latest.xml'
    xml_data = Net::HTTP.get_response(URI.parse(url)).body
  end

  # Add an adivory to the database.
  def add_advisory (advisory)

    # TODO: Just return the record if the advisory already exists.

    # Many advisories don't have a set severity, so give a default.
    if advisory.attributes['severity']
      severity = advisory.attributes['severity']
    else
      severity = 'Unknown'
    end

    # Get all the package names at once to save as details.  We're going to
    # go through them again later, but do this once now to save them with
    # the normal record.  This field will only be to keep the information
    # with the record for manual debugging.
    packages = []
    advisory.elements.each('packages') do |adv_package|
      packages.push(adv_package.text)
    end

    attributes = advisory.attributes
    adv = Advisory.find_or_create_by(name: advisory.name,
                                     description: attributes['description'],
                                     issue_date: attributes['issue_date'],
                                     references: attributes['references'],
                                     kind: attributes['type'],
                                     synopsis: attributes['synopsis'],
                                     severity: severity,
                                     os_family: 'centos',
                                     fix_versions: packages.join("\n"))
    return adv
  end

  # Take a single package name that has a yum advisory filed against it, then
  # parse out that name and find any packages with that name.  Check to see
  # which ones are before the patched version and mark any of those packages
  # as falling under the advisory.
  def check_yum_package (adv, advisory_package)
    m = /^(.+)-([^-]+)-([^-]+)\.(\w+)\.rpm$/.match(advisory_package)
    package_name = m[1]
    package_version = m[2]
    package_subver = m[3]
    package_architecture = m[4]
    return nil if package_architecture == 'src'

    advisory_ver = RPM::Version.new(package_version + '-' + package_subver)
    Package.where(name: package_name, arch: package_architecture,
                  provider: 'yum').find_each do |package|

      check_ver = RPM::Version.new(package.version)
      if (advisory_ver.newer?(check_ver))
        adv.advisories_to_packages.create(package_id: package.id)
      end
    end
  end

  # Main action.  Look up the advisories list, then iterate through all
  # advisories to add and associate them with our packages.
  def index

    # Parse the data and look up.  The file is formatted with every advisory
    # under <opt>.
    xml_data = get_centos_advisories
    doc = REXML::Document.new(xml_data)
    doc.elements.each('opt/*') do |advisory|

      # Skip the meta item, the one thing in the XML that's not an advisory.
      next if advisory.name == 'meta'

      adv = add_advisory(advisory)
      advisory.elements.each('packages') do |adv_package|
        check_yum_package(adv, adv_package.text)
      end
    end
  end
end
