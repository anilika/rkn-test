#! /usr/bin/ruby
require 'rkn_test/version'

require 'curb'
require 'nokogiri'
require 'addressable/uri'

require 'rkn_test/options'
require 'rkn_test/rkn_parser'
require 'rkn_test/output_data'
require 'rkn_test/rkn_downloader'

module RknTest
  class RknTest
    include OutputData

    attr_accessor :not_blocked_pages, :stop_page_title,
                  :unknown_schemes, :fixed_rkn_urls

    def initialize
      options = Options.new
      @fixed_rkn_urls = []
      @unknown_schemes = []
      @not_blocked_pages = []
      @stop_page_title = get_stop_page_title(options.stop_page)
      download_dump = RknDownloader.new(options.request_file, options.signature_file)
      parser = RknParser.new(download_dump.rkn_dump_path)
      fix_schemes(parser.rkn_urls)
      test_urls
      display(unknown_schemes: unknown_schemes, not_blocked_pages: not_blocked_pages)
    end

    def get_stop_page_title(stop_page)
      page = get_urls_data([stop_page]).values.join
      abort 'Stop page does not respond' if page.empty?
      stop_page_title = get_page_title(page)
      abort 'Stop page title is empty' if stop_page_title.empty?
      stop_page_title
    end

    def fix_schemes(rkn_urls)
      rkn_urls.each do |url|
        case Addressable::URI.parse(url).scheme
        when nil
          fixed_rkn_urls.push('http://' + url)
        when 'http', 'https'
          fixed_rkn_urls.push(url)
        else
          unknown_schemes.push(url)
        end
      end
    end

    def test_urls
      data = get_urls_data(fixed_rkn_urls)
      data.each_pair do |url, response|
        title = get_page_title(response)
        not_blocked_pages.push(url) unless titles_equal?(title)
      end
    end

    def get_urls_data(urls)
      data = {}
      easy_options = { follow_location: true, timeout: 3, connect_timeout: 3 }
      multi_options = { pipeline: true }
      urls.each_slice(10) do |urls_group|
        Curl::Multi.get(urls_group, easy_options, multi_options) do |url|
          url.on_success do |resp|
            data[resp.last_effective_url] = resp.body_str
          end
        end
      end
      data
    end

    def get_page_title(page)
      Nokogiri::HTML(page).css('title').text
    end

    def titles_equal?(page_title)
      page_title == stop_page_title
    end
  end
end
