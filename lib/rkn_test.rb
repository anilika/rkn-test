require 'rkn_test/version'

require 'timeout'
require 'nokogiri'
require 'addressable/uri'
require 'open_uri_redirections'

require 'rkn_test/parse_rkn_xml'


module RknTest
  class RknTest
    attr_reader :fixed_rkn_urls, :unknown_schemes, :not_blocked_pages, :stop_page, :stop_page_title
    
    def initialize(rkn_file, stop_page)
      @unknown_schemes = []
      @not_blocked_pages = []
      @stop_page = stop_page
      @stop_page_title = get_page_title(get_url_page(stop_page))
      parse = RknParser.new(rkn_file)
      @fixed_rkn_urls = fix_scheme(parse.rkn_urls)
      test_urls
    end
    
    def fix_scheme(rkn_urls)
      rkn_urls.map do |url|
        case Addressable::URI.parse(url).scheme
        when nil
          url = "http://" + url
        when 'http', 'https'
        else
          @unknown_schemes.push(url)
        end
      end
    end
    
    def test_urls
      fixed_rkn_urls.each do |url|
        next unless page = get_url_page(url)
        page_title = get_page_title(page)
        not_blocked_pages.push(url) unless titles_equal?(page_title)
      end
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
      page.css('title').text
    end

    def titles_equal?(page_title)
      page_title == stop_page_title
    end
  end
    
  my_test = RknTest.new('/home/alisa/dump_line.xml', 'http://forbidden.page')
  print my_test.unknown_schemes
end
