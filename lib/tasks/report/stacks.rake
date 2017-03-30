namespace :report do
  desc 'Report on stack status'
  task :stacks, [:name, :output_type] => :environment do |_t, args|
    require "#{Rails.root}/app/helpers/stack_report_helper"
    include StackReportHelper

    stack = args[:name]
    output_type = args[:output_type] || 'stdout'

    kernel_header = ''
    kernel_header << "The following kernel packages and advisories will be\n"
    kernel_header << "updated next Thursday morning starting at 6AM.\n"

    gem_header = ''
    gem_header << "The following gemfiles on the system have open advisories\n"
    gem_header << "and need to be patched.  Please check applications that\n"
    gem_header << "might be including them to update, or ask the operations\n"
    gem_header << "group for help.\n"

    # Temp filler while Tony does puppet integration.
    hosts = [stack]

    # Go through each host, get kernel and gem advisories, and make the report.
    output = ''
    hosts.sort.each do |hostname|
      kernel = Report.new.advisories(hostname, 'kernel')
      gems = Report.new.advisories(hostname, '', 'gem')
      next if kernel.empty? && gems.empty?

      output << format("%s\n", hostname)
      output << report_stanza(kernel, kernel_header)
      output << report_stanza(gems, gem_header)
      output << "\n"
    end

    # Either print or email the report, depending on argument.
    if output_type == 'email'
      ReportMailer.stacks_email(stack, output).deliver_now
    else
      print output
    end
  end
end
