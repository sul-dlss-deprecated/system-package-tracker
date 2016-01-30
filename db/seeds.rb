# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)
System.create!(hostname: 'testbox-prod', os: 'redhat')
Package.create!(name: 'qemu-kvm-rhev', version: '2.3.0-31', repository: 'rhel-el6')
# cve_id should be an array instead
Vulnerability.create!(advisory_id: 'RHSA-2016:0088', severity: 'Important', date_reported: '2016-01-28', synopsis: 'Important: qemu-kvm-rhev security update', cve_id: 'CVE-2016-1568')
