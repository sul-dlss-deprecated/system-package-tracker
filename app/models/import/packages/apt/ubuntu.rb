# Loading advisory data for Ubuntu apt packages.
class Import
  class Packages
    class Apt
      class Ubuntu < Import::Packages::Apt
        LOGFILE       = 'log/import.log'.freeze
        LOGLEVEL      = Logger::INFO

        PROXY_ADDR    = 'swp.stanford.edu'.freeze
        PROXY_PORT    = 80

        def import_advisories
        end

        def import_source
        end

        private

        def add_record
        end
        
        # Wrapper for doing logging of our import statuses for debugging.
        def log
          if @logger.nil?
            @logger = Logger.new(LOGFILE, 'monthly')
            @logger.level = LOGLEVEL
          end
          @logger
        end

      end
    end
  end
end
