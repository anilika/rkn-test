#! /usr/bin/ruby
require 'rkn_test/version'

require 'timeout'
require 'nokogiri'
require 'thread/pool'
require 'addressable/uri'
require 'open_uri_redirections'

require 'rkn_test/parse_rkn_xml'
require 'rkn_test/rkn_downloader'
require 'rkn_test/options'
require 'rkn_test/output_data'

module RknTest
  class RknTest
    include OutputData
    
    attr_reader :fixed_rkn_urls, :unknown_schemes, :not_blocked_pages, :stop_page, :stop_page_title
    attr_accessor :rkn_urls

    def initialize
      options = Options.new
      @unknown_schemes = []
      @not_blocked_pages = []
      @stop_page = options.stop_page
      @stop_page_title = get_page_title(get_url_page(stop_page))
      download_dump = RknDownloader.new(options.request_file, options.signature_file)
      parse = RknParser.new(download_dump.rkn_dump_path)
      @fixed_rkn_urls = fix_scheme(parse.rkn_urls)
      test_urls
      display({ unknown_schemes: unknown_schemes, not_blocked_pages: not_blocked_pages })
    end

    def fix_scheme(rkn_urls)
      rkn_urls.map do |url|
        case Addressable::URI.parse(url).scheme
        when nil
          url = "http://" + url
        when 'http', 'https'
          url
        else
          @unknown_schemes.push(url)
        end
      end
    end

    def test_urls
      pool = Thread.pool(100)
      pool.process do
        fixed_rkn_urls.each do |url|
          puts url
          next unless page = get_url_page(url)
          page_title = get_page_title(page)
          not_blocked_pages.push(url) unless titles_equal?(page_title)
        end
      end
      pool.shutdown
    end

    def get_url_page(url)
      begin
        Timeout.timeout(1) do
          Nokogiri::HTML(open(url, :allow_redirections => :all))
        end
      rescue Timeout::Error, SocketError, Errno::ECONNRESET, Errno::ECONNREFUSED
        false
      rescue StandardError
        @not_blocked_pages.push(url)
        false
      end
    end

    def get_page_title(page)
      begin
        page.css('title').text
      rescue NoMethodError
        abort "Stop page #{page} does not respond"
      end
    end

    def titles_equal?(page_title)
      page_title == stop_page_title
    end
  end
end
