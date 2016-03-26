#! /usr/bin/ruby
require 'rkn_test/version'

require 'curb'
require 'nokogiri'
require 'thread/pool'
require 'addressable/uri'

require 'rkn_test/parse_rkn_xml'
require 'rkn_test/rkn_downloader'
require 'rkn_test/options'
require 'rkn_test/output_data'

module RknTest
  class RknTest
    include OutputData

    attr_reader :fixed_rkn_urls, :unknown_schemes, :not_blocked_pages, :stop_page, :stop_page_title
    attr_accessor :rkn_urls, :http_client

    def initialize
      options = Options.new
      @unknown_schemes = []
      @not_blocked_pages = []
      @http_client = config_http_client
      @stop_page = options.stop_page
      @stop_page_title = get_stop_page_title
      download_dump = RknDownloader.new(options.request_file, options.signature_file)
      parse = RknParser.new(download_dump.rkn_dump_path)
      @fixed_rkn_urls = fix_scheme(parse.rkn_urls)
      test_urls
      display(unknown_schemes: unknown_schemes, not_blocked_pages: not_blocked_pages)
    end

    def get_stop_page_title
      page = get_url_page(stop_page)
      abort "Stop page #{page} does not respond" unless page
      stop_page_title = get_page_title(page)
      abort 'Stop page title is empty' if stop_page_title.empty?
    end

    def fix_scheme(rkn_urls)
      rkn_urls.map do |url|
        case Addressable::URI.parse(url).scheme
        when nil
          'http://' + url
        when 'http', 'https'
          url
        else
          @unknown_schemes.push(url)
        end
      end
    end
    
    def config_http_client
      http_client = Curl::Easy.new
      http_client.timeout = 3
      http_client.connect_timeout = 3
      http_client.follow_location = true
    end

    def test_urls
      pool = Thread.pool(100)
      fixed_rkn_urls.each do |url|
        pool.process do
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
        http_client.url = url
        http_client.perform
        Nokogiri::HTML(http_client.body_str)
      rescue Curl::Err::TimeoutError, Curl::Err::HostResolutionError,
        Curl::Err::ConnectionFailedError, SocketError, Errno::ECONNRESET,
        Errno::ECONNREFUSED
        false
      rescue StandardError
        @not_blocked_pages.push(url)
        false
      end
    end

    def get_page_title(page)
      page.css('title').text
    end

    def titles_equal?(page_title)
      page_title == stop_page_title
    end
  end
end
