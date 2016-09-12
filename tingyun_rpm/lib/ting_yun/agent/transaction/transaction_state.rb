# encoding: utf-8

require 'ting_yun/agent/transaction/traced_method_stack'
require 'ting_yun/agent/transaction/transaction_timings'
module TingYun
  module Agent

    # This is THE location to store thread local information during a transaction
    # Need a new piece of data? Add a method here, NOT a new thread local variable.
    class TransactionState

      # Request data
      attr_accessor :transaction_sample_builder
      attr_reader   :current_transaction, :traced_method_stack
      # Sql Sampler Transaction Data
      attr_accessor :sql_sampler_transaction_data,
                    :client_transaction_id,
                    :client_tingyun_id_secret,
                    :client_req_id,
                    :thrift_return_data







      def self.tl_get
        tl_state_for(Thread.current)
      end

      # This method should only be used by TransactionState for access to the
      # current thread's state or to provide read-only accessors for other threads
      #
      # If ever exposed, this requires additional synchronization
      def self.tl_state_for(thread)
        state = thread[:tingyun_transaction_state]

        if state.nil?
          state = TransactionState.new
          thread[:tingyun_transaction_state] = state
        end

        state
      end

      def initialize
        @untraced = []
        @current_transaction = nil
        @traced_method_stack = TingYun::Agent::TracedMethodStack.new
      end

      # This starts the timer for the transaction.
      def reset(transaction=nil)
        # We purposefully don't reset @untraced, @record_tt and @record_sql
        # since those are managed by TingYun::Agent.disable_* calls explicitly
        # and (more importantly) outside the scope of a transaction
        @current_transaction = transaction
        @traced_method_stack.clear
        @transaction_sample_builder = nil
        @sql_sampler_transaction_data = nil
        @cross_tx_data = nil
        @thrift_return_data = nil
        @timings = nil
      end

      # TT's and SQL
      attr_accessor :record_tt, :record_sql
      attr_accessor :untraced

      def push_traced(should_trace)
        @untraced << should_trace
      end

      def pop_traced
        @untraced.pop if @untraced
      end

      def execution_traced?
        @untraced.nil? || @untraced.last != false
      end

      def sql_recorded?
        @record_sql != false
      end

      def transaction_traced?
        @record_tt != false
      end

      def request_guid
        return nil unless current_transaction
        current_transaction.guid
      end

      class Timings <  Struct.new :sql_duration, :external_duration, :rds_duration, :mc_duration, :mon_duration; end


      def timings
        @timings ||= TingYun::Agent::TransactionTimings.new(transaction_queue_time, transaction_start_time, transaction_name, trace_id, Timings.new)
      end

      def transaction_start_time
        current_transaction.nil? ? 0.0 : current_transaction.start_time
      end

      def transaction_queue_time
        current_transaction.nil? ? 0.0 : current_transaction.queue_time
      end

      def transaction_name
        current_transaction.nil? ? nil : current_transaction.best_name
      end

      def trace_id
        transaction_sample_builder.nil? ? nil : transaction_sample_builder.trace.guid
      end





    end
  end
end
