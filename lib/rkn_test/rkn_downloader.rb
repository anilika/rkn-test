require 'savon'
require 'base64'
require 'rubygems'
require 'zip'

module RknTest
  class RknDownloader
    RKN_WSDL = 'http://vigruzki.rkn.gov.ru/services/OperatorRequestTest/?wsdl'
    
    attr_reader :client, :request_file, :signature_file,
        :code, :rkn_archive, :rkn_dump_path, :rkn_archive_path
    
    def initialize(
      request_file,
      signature_file,
      rkn_dump_path = '/tmp/rkn_dump.xml',
      rkn_archive_path = '/tmp/rkn_dump.xml'
      )
      
      @rkn_dump_path = rkn_dump_path
      @rkn_archive_path = rkn_archive_path
      @client = create_soap_client
      @request_file = encode64(request_file)
      @signature_file = encode64(signature_file)
      @code = get_rkn_queue_code(send_request)
      @rkn_archive = decode64(get_base64_rkn_archive(get_rkn_queue_response))
      save_rkn_archive
      extract_rkn_dump
    end 
    
    def send_request
      client.call(:send_request,
        message: {
          requestFile: request_file,
          signatureFile: signature_file,
          dumpFormatVersion: '2.2'})
    end
    
    def get_rkn_queue_code(response)
      response.body[:send_request_response][:code]
    end
    
    def get_rkn_queue_response
      client.call(:get_result, message: {code: code})
    end
    
    def get_base64_rkn_archive(response)
      response.body[:get_result_response][:register_zip_archive]
    end
    
    def save_rkn_archive
      File.open(rkn_archive_path, 'w') do |file|
        file.write(rkn_archive)
      end
    end
    
    def extract_rkn_dump
      zip_file = Zip::File.open(rkn_archive_path)
      zip_file.extract('dump.xml', rkn_dump_path){true}
    end
    
    def create_soap_client
      Savon.client(wsdl: RKN_WSDL, follow_redirects: 'true')
    end
    
    def encode64(file)
      Base64.encode64(File.read(file))
    end
    
    def decode64(data)
      Base64.decode64(data)
    end
  end
  
  n = RknDownloader.new('Development/rkn-reg/req.xml', 'Development/rkn-reg/req.xml.sig')
  puts n.rkn_dump_path
end

#client = Savon.client(wsdl: 'http://vigruzki.rkn.gov.ru/services/OperatorRequestTest/?wsdl', follow_redirects: 'true')
#file = Base64.encode64(File.read('Development/rkn-reg/req.xml'))
#signature_file = Base64.encode64(File.read('Development/rkn-reg/req.xml.sig'))
#response = client.call(:send_request, message: { requestFile: file, signatureFile: signature_file, dumpFormatVersion: '2.2'})
#code = response.body[:send_request_response][:code]
#response_2 = client.call(:get_result, message: {code: code})
#zip_file_64 = response_2.body[:get_result_response][:register_zip_archive]
#File.open('zip_rkn_file', 'w') do |f|
#  f.write(Base64.decode64(zip_file_64))
#end

#zip_file = Zip::File.open('zip_rkn_file')
#zip_file.extract('dump.xml', 'dumps.xml')

#ip::File.open_buffer(io, options = {}) {|zf| ... } ⇒ Object 

