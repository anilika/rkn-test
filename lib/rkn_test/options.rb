require 'optparse'

module RknTest
  class Options 
    attr_reader :options
    def initialize
      @options = {}
      parse_args
      options.each do |k, v|
        self.class.class_eval do
          attr_accessor k
        end
        self.instance_variable_set "@#{k}", v
      end
    end
    
    def parse_args
      optparse = OptionParser.new do |opts|
        opts.banner = "Required options: -f, -r, -s"
        
        opts.on("-f", "--forbidden FORBIDDEN", "Url forbidden page") do |forbidden|
          options[:stop_page] =  forbidden
        end
        opts.on("-r", "--request_file REQUEST_FILE", "Request file for upload") do |request|
          options[:request_file] = request
        end
        opts.on("-s", "--signature SIGNATURE", "Detached electronic signature") do |signature|
          options[:signature_file] = signature
        end
        opts.on("-d", "--dump_path DUMP_PATH", "Specify where to save dump") do |dump|
          options[:rkn_dump_path] = dump
        end
        opts.on("-a", "--archive_path ARCHIVE_PATH", "Specify where to save archive") do |archive|
          options[:rkn_archive_path] = archive
        end
        opts.on("-h", "--help", "Prints this help") do
          puts opts
          exit
        end
      end
      begin
        optparse.parse!
        mandatory = [:stop_page, :request_file, :signature_file] 
        missing = mandatory.select { |param| options[param].nil? }
        unless missing.empty?
          puts "Missing options: #{missing.join(', ')}"
          puts optparse
          exit
        end
      rescue OptionParser::InvalidOption, OptionParser::MissingArgument
        puts $!.to_s
        puts optparse
        exit
      end     
    end
  end
end
