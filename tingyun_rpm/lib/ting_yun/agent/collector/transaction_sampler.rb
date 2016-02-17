# encoding: utf-8

require 'ting_yun/agent/transaction_sample_builder'
require 'ting_yun/agent/collector/transaction_sampler/slowest_sample_buffer'

module TingYun
  module Agent
    module Collector
      class TransactionSampler

        attr_reader :last_sample

        def initialize
          @lock = Mutex.new
          @sample_buffers = []
          @sample_buffers << TingYun::Agent::Collector::TransactionSampler::SlowestSampleBuffer.new
        end


        def notice_push_frame(state, time=Time.now)
          builder = state.transaction_sample_builder
          return unless builder
          builder.trace_entry(time.to_f)
        end

        # Informs the transaction sample builder about the end of a traced frame
        def notice_pop_frame(state, frame, time = Time.now)
          builder = state.transaction_sample_builder
          return unless builder
          builder.trace_exit(frame, time.to_f)
        end

        def enabled?
          TingYun::Agent.config[:'nbs.action_tracer.enabled']
        end

        def on_start_transaction(state, time)
          start_builder(state, time)
        end

        def start_builder(state, time=nil)
          if enabled?
            state.transaction_sample_builder ||= TingYun::Agent::TransactionSampleBuilder.new(time)
          else
            state.transaction_sample_builder = nil
          end
        end


        def on_finishing_transaction(state, txn, time=Time.now)
          last_builder = state.transaction_sample_builder
          return unless last_builder && enabled?

          state.transaction_sample_builder = nil

          last_trace = last_builder.trace
          last_trace.transaction_name = txn.best_name
          last_trace.uri = txn.request_path
          last_trace.guid = txn.guid
          last_trace.attributes = txn.response_attributes

          @lock.synchronize do
            @last_sample = last_trace
            store_sample(@last_sample)
            @last_sample
          end
        end

        def store_sample(sample)
          @sample_buffers.each do |sample_buffer|
            sample_buffer.store(sample)
          end
        end

        def notice_nosql_statement(statement, duration)

        end







        def reset!
          @lock.synchronize do
            @sample_buffers.each { |sample| sample.reset! }
          end
        end
      end
    end
  end
end
