# encoding: utf-8

require 'ting_yun/agent/transaction/transaction_state'
require 'ting_yun/instrumentation/support/transaction_namer'
require 'ting_yun/agent/transaction'
require 'ting_yun/agent'


module TingYun
  module Instrumentation
    module Support
      module ControllerInstrumentation

        extend self

        NR_DEFAULT_OPTIONS    = {}.freeze          unless defined?(NR_DEFAULT_OPTIONS   )

        def perform_action_with_tingyun_trace (*args, &block)

          state = TingYun::Agent::TransactionState.tl_get

          trace_options = args.last.is_a?(Hash) ? args.last : NR_DEFAULT_OPTIONS
          category = trace_options[:category] || :controller
          txn_options = create_transaction_options(trace_options, category)

          begin
            TingYun::Agent::Transaction.start(state, category, txn_options)
            begin
              yield
            rescue => e
              ::TingYun::Agent.notice_error(e)
              raise
            end
          ensure
            TingYun::Agent::Transaction.stop(state)
          end
        end

        private

        def create_transaction_options(trace_options, category)
          txn_options = {}

          txn_options[:request] ||= request if respond_to?(:request)
          txn_options[:request] ||= trace_options[:request] if trace_options[:request]
          txn_options[:filtered_params] = trace_options[:params]
          txn_options[:transaction_name] = TingYun::Instrumentation::Support::TransactionNamer.name_for(nil, self, category, trace_options)
          txn_options[:apdex_start_time] = Time.now

          txn_options
        end
      end
    end
  end

end
