module StackReportHelper

  # Create the a standard section for our lists.  This creates a simple list
  # of packages with open advisories, and the advisory for each, with a header
  # statement.
  def report_stanza(advisories, header = '')
    output = ''
    return output if advisories.empty?

    output << "\n"
    output << header if header != ''
    advisories.keys.sort.each do |host|
      advisories[host].keys.sort.each do |package|
        advisories[host][package].keys.sort.each do |version|
          unique_pkg = package + '-' + version
          output << format("    %s\n", unique_pkg)
          advisories[host][package][version].each do |advisory|
            output << format("        %-10s %s\n", advisory['severity'],
                             advisory['references'])
          end
        end
      end
    end
    output << "\n"
    output
  end
end
