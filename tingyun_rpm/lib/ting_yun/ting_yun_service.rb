# encoding: utf-8
# This file is distributed under Ting Yun's license terms.


require 'ting_yun/agent'
require 'zlib'
require 'ting_yun/ting_yun_service/http'
require 'ting_yun/support/collector'
require 'ting_yun/support/serialize/encodes'
require 'ting_yun/support/timer_lib'
require 'ting_yun/support/exception'
require 'ting_yun/support/serialize/json_marshaller'
require 'ting_yun/ting_yun_service/upload_service'
require 'ting_yun/version'

module TingYun
  class TingYunService
    include Http
    include UploadService

    CONNECTION_ERRORS = [Timeout::Error, EOFError, SystemCallError, SocketError].freeze

    PROTOCOL_VERSION = 1


    attr_accessor :request_timeout, :ting_yun_id_secret, :app_session_key, :data_version, :metric_id_cache

    def initialize(license_key=nil,collector=TingYun::Support.collector)
      @applicationId = nil
      @appSessionKey = nil
      @license_key = license_key || TingYun::Agent.config[:'license_key']
      @request_timeout = TingYun::Agent.config[:timeout]
      @collector = collector
      @ting_yun_id_secret = nil
      @ssl_cert_store = nil
      @shared_tcp_connection = nil
      @data_version = TingYun::VERSION::STRING
      @marshaller =TingYun::Support::Serialize::JsonMarshaller.new
      @metric_id_cache = {}
    end

    def connect(settings={})
      if host = get_redirect_host
         @collector = TingYun::Support.collector_from_host(host)
      end
      response = invoke_remote(:initAgentApp, [settings])
      TingYun::Agent.logger.info("initAgentApp response: #{response}") if TingYun::Agent.config[:'nbs.audit_mode']
      @applicationId = response['applicationId']
      @appSessionKey = response['appSessionKey']
      response
    end

    def get_redirect_host
      invoke_remote(:getRedirectHost)
    end

    def force_restart
      @metric_id_cache = {}
      close_shared_connection
    end

    # send a message via post to the actual server. This attempts
    # to automatically compress the data via zlib if it is large
    # enough to be worth compressing, and handles any errors the
    # server may return

    # private

    def invoke_remote(method, payload=[], options = {})

      data, size, serialize_finish_time = nil
      payload = payload[0]  if method == :initAgentApp
      begin
        data = @marshaller.dump(payload, options)
      rescue StandardError, SystemStackError => e
        handle_serialization_error(method, e)
      end
      serialize_finish_time = Time.now

      data, encoding = compress_request_if_needed(data)
      size = data.size

      TingYun::Agent.logger.info("the prepare data: #{data}") if TingYun::Agent.config[:'nbs.audit_mode']

      uri = remote_method_uri(method)
      full_uri = "#{@collector}#{uri}"
      TingYun::Agent.logger.info("url: #{full_uri}") if TingYun::Agent.config[:'nbs.audit_mode']
      response = send_request(:data      => data,
                              :uri       => uri,
                              :encoding  => encoding,
                              :collector => @collector)
      TingYun::Agent.logger.info("the return data: #{response.body}") if TingYun::Agent.config[:'nbs.audit_mode']
      @marshaller.load(decompress_response(response))
    end

    def handle_serialization_error(method, e)
      msg = "Failed to serialize #{method} data using #{@marshaller.class.to_s}: #{e.inspect}"
      error = TingYun::Support::Exception::SerializationError.new(msg)
      error.set_backtrace(e.backtrace)
      raise error
    end







  end
end