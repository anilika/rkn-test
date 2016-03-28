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
    EASY_OPTIONS = { follow_location: true, timeout: 3, connect_timeout: 3 }.freeze
    MULTI_OPTIONS = { pipeline: Curl::CURLPIPE_HTTP1 }.freeze
    
    include OutputData

    attr_reader :fixed_rkn_urls, :unknown_schemes, :not_blocked_pages, :stop_page, :stop_page_title
    attr_accessor :rkn_urls, :titles_urls

    def initialize
      options = Options.new
      @unknown_schemes = []
      @not_blocked_pages = []
      @fixed_rkn_urls = []
      @titles_urls = {}
      @stop_page = options.stop_page
      @stop_page_title = get_stop_page_title
      download_dump = RknDownloader.new(options.request_file, options.signature_file)
      parse = RknParser.new(download_dump.rkn_dump_path)
      fix_scheme(parse.rkn_urls)
      test_urls
      display(unknown_schemes: unknown_schemes, not_blocked_pages: not_blocked_pages)
    end

    def get_stop_page_title
      page = ''
      get_url_page(stop_page) { |url| page = url.body_str }
      abort 'Stop page does not respond' unless page
      stop_page_title = get_page_title(page)
      abort 'Stop page title is empty' if stop_page_title.empty?
      stop_page_title
    end

    def fix_scheme(rkn_urls)
      rkn_urls.each do |url|
        case Addressable::URI.parse(url).scheme
        when nil
          @fixed_rkn_urls.push('http://' + url)
        when 'http', 'https'
          @fixed_rkn_urls.push(url)
        else
          @unknown_schemes.push(url)
        end
      end
    end

    def test_urls
      get_url_page(fixed_rkn_urls) do |url|
        next unless page = url.body_str
        page_title = get_page_title(page)
        not_blocked_pages.push(url.last_effective_url) unless titles_equal?(page_title)
      end
    end

    def get_url_page(urls)
      begin
        urls.each_slice(10) do |links|
          Curl::Multi.get(links, EASY_OPTIONS, MULTI_OPTIONS) do |url|
            yield url
          end
        end
      rescue Curl::Err::TimeoutError, Curl::Err::HostResolutionError,
        Curl::Err::ConnectionFailedError, SocketError, Errno::ECONNRESET,
        Errno::ECONNREFUSED
        false
      rescue StandardError
        not_blocked_pages.push(url)
        false
      end
    end

    def get_page_title(page)
      Nokogiri::HTML(page).css('title').text
    end

    def titles_equal?(page_title)
      page_title == stop_page_title
    end
  end
end
