require 'zip'
require 'savon'
require 'base64'

module RknTest
  class RknDownloader
    RKN_WSDL = 'http://vigruzki.rkn.gov.ru/services/OperatorRequest/?wsdl'
               .freeze

    attr_reader :client, :request_file, :signature_file, :queue_code,
                :rkn_archive_data, :rkn_dump_path, :rkn_archive_path

    def initialize(
      request_file,
      signature_file,
      rkn_dump_path = '/tmp/rkn_dump.xml',
      rkn_archive_path = '/tmp/rkn_dump.zip')

      @rkn_dump_path = rkn_dump_path
      @rkn_archive_path = rkn_archive_path
      @client = connect_rkn_rpc
      @request_file = encode64(request_file)
      @signature_file = encode64(signature_file)
      @queue_code = get_rkn_queue_code(send_request)
      @rkn_archive_data = decode64(get_rkn_queue_response)
      save_rkn_archive
      extract_rkn_xml_dump
    end

    def send_request
      client.call(:send_request,
                  message: { requestFile: request_file,
                             signatureFile: signature_file,
                             dumpFormatVersion: '2.2' })
    end

    def get_rkn_queue_code(response)
      unless response.body[:send_request_response][:result]
        abort response.body[:send_request_response][:result_comment]
      end
      response.body[:send_request_response][:code]
    end

    def get_rkn_queue_response
      result = false
      until result
        response = client.call(:get_result, message: { code: queue_code })
        case response.body[:get_result_response][:result_code]
        when '1'
          break
        when '0'
          sleep(65)
        else
          abort response.body[:get_result_response][:result_comment]
        end
      end
      get_base64_rkn_archive(response)
    end

    def get_base64_rkn_archive(response)
      response.body[:get_result_response][:register_zip_archive]
    end

    def save_rkn_archive
      File.open(rkn_archive_path, 'w') { |file| file.write(rkn_archive_data) }
    end

    def extract_rkn_xml_dump
      zip_file = Zip::File.open(rkn_archive_path)
      zip_file.extract('dump.xml', rkn_dump_path) { true }
    end

    def connect_rkn_rpc
      Savon.client(wsdl: RKN_WSDL, follow_redirects: 'true')
    end

    def encode64(file)
      begin
        Base64.encode64(File.read(file))
      rescue Errno::ENOENT => e
        abort e.to_s
      end
    end

    def decode64(data)
      Base64.decode64(data)
    end
  end
end
