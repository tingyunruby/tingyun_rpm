# encoding: utf-8

require 'ting_yun/agent/transaction/transaction_state'
require 'ting_yun/agent/transaction'
require 'ting_yun/support/http_clients/uri_util'
require 'ting_yun/support/serialize/json_wrapper'

module TingYun
  module Agent
    module CrossAppTracing

      # Exception raised if there is a problem with cross app transactions.
      class Error < RuntimeError; end

      # The cross app id header for "outgoing" calls

      TY_ID_HEADER = 'X-Tingyun-Id'.freeze
      TY_DATA_HEADER = 'X-Tingyun-Tx-Data'.freeze




      module_function

      def tl_trace_http_request(request)
        t0 = Time.now.to_f
        state = TingYun::Agent::TransactionState.tl_get
        return yield unless state.execution_traced?
        begin
          node = start_trace(state, t0, request)
          response = yield
        ensure
          finish_trace(state, t0, node, request, response)
        end
        return response
      end

      def start_trace(state, t0, request)
        inject_request_headers(state, request) if cross_app_enabled?
        stack = state.traced_method_stack
        node = stack.push_frame(state,:http_request,t0)

        return node
      end

      def finish_trace(state, t0, node, request, response)
        t1 = Time.now.to_f
        duration = (t1- t0) * 1000
        state.external_duration = duration

        begin
          if request
            metrics = metrics_for(state, request, response)
            node_name = metrics.pop
            scoped_metric = metrics.pop

            stats_engine.record_scoped_and_unscoped_metrics(state, scoped_metric, metrics, duration)

            if node
              node.name = node_name
              add_transaction_trace_info(request, response)
            end
          end
        ensure
          if node
            stack = state.traced_method_stack
            stack.pop_frame(state, node, node_name, t1)
          end
        end
      rescue => err
        TingYun::Agent.logger.error "Uncaught exception while finishing an HTTP request trace", err

      end

      def add_transaction_trace_info(request, response)
        filtered_uri = TingYun::Agent::HTTPClients::URIUtil.filter_uri request.uri
        transaction_sampler.add_node_info(:uri => filtered_uri)
        if response && response_is_cross_app?( response )
          my_data = TingYun::Support::Serialize::JSONWrapper.load response[TY_DATA_HEADER].gsub("'",'"')
          transaction_sampler.tl_builder.current_node[:txId] = my_data["trId"]
          transaction_sampler.tl_builder.current_node[:txData] = my_data
        end
      end

      def metrics_for(state, request, response)
        metrics = common_metrics(request)

        if response && response_is_cross_app?( response )
          begin
            metrics.concat metrics_for_cross_app_response( request, response )
          rescue => err
            # Fall back to regular metrics if there's a problem with x-process metrics
            TingYun::Agent.logger.debug "%p while fetching x-process metrics: %s" %
                                             [ err.class, err.message ]
            metrics.concat metrics_for_regular_request( request )
          end
        else
          metrics.concat metrics_for_regular_request( request )
        end

        return metrics
      end

      def common_metrics(request)
        metrics = [ "External/NULL/ALL" ]

        if TingYun::Agent::Transaction.recording_web_transaction?
          metrics << "External/NULL/AllWeb"
        else
          metrics << "External/NULL/AllBackground"
        end

        return metrics
      end

      def metrics_for_regular_request( request )
        metrics = []
        metrics << "External/#{request.host}/#{request.type}/#{request.method}"
        metrics << "External/#{request.host}/#{request.type}/#{request.method}"

        return metrics
      end

      def stats_engine
        ::TingYun::Agent.instance.stats_engine
      end

      def transaction_sampler
        ::TingYun::Agent.instance.transaction_sampler
      end


      def cross_app_enabled?
        valid_tingyun_secret_id? && web_action_tracer_enabled? && cross_application_tracer_enabled?
      end

      def web_action_tracer_enabled?
        TingYun::Agent.config[:'nbs.action_tracer.enabled']
      end

      def cross_application_tracer_enabled?
        TingYun::Agent.config[:'nbs.transaction_tracer.enabled']
      end

      def valid_tingyun_secret_id?
        TingYun::Agent.config[:tingyunIdSecret] && TingYun::Agent.config[:tingyunIdSecret].size > 0
      end

      # Inject the X-Process header into the outgoing +request+.
      def inject_request_headers(state, request)
        cross_app_id  = TingYun::Agent.config[:tingyunIdSecret] or
            raise TingYun::Agent::CrossAppTracing::Error, "no tingyunIdSecret configured"

        txn_guid = state.request_guid

        request[TY_ID_HEADER] = "#{cross_app_id};c=1;x=#{txn_guid}"

      rescue TingYun::Agent::CrossAppTracing::Error => err
        TingYun::Agent.logger.debug "Not injecting x-process header", err
      end

      # Returns +true+ if Cross Application Tracing is enabled, and the given +response+
      # has the appropriate headers.
      def response_is_cross_app?( response )
        return false unless cross_app_enabled?
        unless response[TY_DATA_HEADER]
          return false
        end
        return true
      end

      # Return the set of metric objects appropriate for the given cross app
      # +response+.
      def metrics_for_cross_app_response(request, response )
        my_data =  TingYun::Support::Serialize::JSONWrapper.load response[TY_DATA_HEADER].gsub("'",'"')
        uri = "#{request.host}/#{request.type}/#{request.method}"
        metrics = []
        metrics << "cross_app;#{my_data["id"]};#{my_data["action"]};#{uri}"
        metrics << "External/#{my_data["action"]}:#{uri}"

        return metrics
      end

    end
  end
end