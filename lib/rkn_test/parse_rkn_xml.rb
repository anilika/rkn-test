
module RknTest
  class RknParser
    attr_reader :rkn_urls
     
    def initialize(rkn_file)
      @rkn_urls = []
      @rkn_xml_data = read_rkn_xml(rkn_file)
      parser
    end
     
    def read_rkn_xml(rkn_file)
      Nokogiri::XML(File.open(rkn_file))
    end
     
    def parser
      @rkn_xml_data.xpath('//content').each do |content|
        if content.at_xpath('url')
          content.xpath('url').each do |url|
            @rkn_urls.push(url.text)
          end
        else
          @rkn_urls.push(content.xpath('domain').text)
        end
      end
    end
  end
end
