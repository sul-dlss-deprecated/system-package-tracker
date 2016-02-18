require 'rails_helper'

RSpec.describe ImportController, type: :controller do
  describe '#save_server' do
    it 'adds new host to db' do
      host = 'testhost.stanford.edu'
	  os_release = 'centos6'
	  report_time = '2016-01-01 01:23:45'
	  server = ImportController.new.save_server(host, os_release, report_time)

      expect(server.hostname).to eq(host)
      expect(server.os_release).to eq(os_release)
      expect(server.last_checkin).to eq(report_time)
	end
    it 'updates existing host in db' do

      # TODO: Add associations to packages and test that they're removed.

      host = 'testhost.stanford.edu'
	  os_release = 'centos7'
	  report_time = '2016-02-02 01:23:45'
	  server = ImportController.new.save_server(host, os_release, report_time)

      expect(server.hostname).to eq(host)
      expect(server.os_release).to eq(os_release)
      expect(server.last_checkin).to eq(report_time)
	end
  end

end
