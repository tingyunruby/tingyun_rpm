# encoding: utf-8
require 'ting_yun/middleware/agent_middleware'
require 'ting_yun/instrumentation/support/javascript_instrumentor'


module TingYun
  class BrowserMonitoring < AgentMiddleware

    CONTENT_TYPE        = 'Content-Type'.freeze
    TEXT_HTML           = 'text/html'.freeze
    CONTENT_DISPOSITION = 'Content-Disposition'.freeze
    ATTACHMENT          = 'attachment'.freeze

    SCAN_LIMIT          = 64_000

    TITLE_END           = '</title>'.freeze
    TITLE_END_CAPITAL   = '</TITLE>'.freeze
    HEAD_END            = '</head>'.freeze
    HEAD_END_CAPITAL    = '</HEAD>'.freeze

    GT                  = '>'.freeze




    def traced_call(env)
      result = @app.call(env)   # [status, headers, response]

      js_to_inject = TingYun::Instrumentation::Support::JavascriptInstrument.browser_timing_header

      if (js_to_inject != '') && should_instrument?(env, result[0], result[1])
        response_string = auto_instrument_source(result[2], js_to_inject)

        env[ALREADY_INSTRUMENTED_KEY] = true
        if response_string
          response = Rack::Response.new(response_string, result[0], result[1])
          response.finish
        else
          result
        end
      else
        result
      end
    end

    ALREADY_INSTRUMENTED_KEY = "tingyun.browser_monitoring_already_instrumented"

    def should_instrument?(env, status, headers)
      status == 200 &&
          !env[ALREADY_INSTRUMENTED_KEY] &&
          is_html?(headers) &&
          !is_attachment?(headers)
    end

    def is_html?(headers)
      headers[CONTENT_TYPE] && headers[CONTENT_TYPE].include?(TEXT_HTML)
    end

    def is_attachment?(headers)
      headers[CONTENT_DISPOSITION] && headers[CONTENT_DISPOSITION].include?(ATTACHMENT)
    end

    def auto_instrument_source(response, js_to_inject)
      source = gather_source(response)
      close_old_response(response)
      return nil unless source

      beginning_of_source = source[0..SCAN_LIMIT]
      insertion_index = find_tag_end(beginning_of_source)

      if insertion_index
        source = source[0...insertion_index] <<
            js_to_inject <<
            source[insertion_index..-1]
      else
        TingYun::Agent.logger.debug "Skipping RUM instrumentation. Could not properly determine location to inject script."
      end

      source
    rescue => e
      TingYun::Agent.logger.debug "Skipping RUM instrumentation on exception.", e
      nil
    end

    def gather_source(response)
      source = nil
      response.each {|fragment| source ? (source << fragment.to_s) : (source = fragment.to_s)}
      source
    end

    def close_old_response(response)
      if response.respond_to?(:close)
        response.close
      end
    end

    def find_tag_end(beginning_of_source)
      tag_end = beginning_of_source.index(TITLE_END) ||
          beginning_of_source.index(HEAD_END) ||
          beginning_of_source.index(TITLE_END_CAPITAL) ||
          beginning_of_source.index(HEAD_END_CAPITAL)

      beginning_of_source.index(GT, tag_end) + 1 if tag_end
    end
  end
end
