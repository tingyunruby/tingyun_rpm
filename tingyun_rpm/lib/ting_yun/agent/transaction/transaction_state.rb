# encoding: utf-8

require 'ting_yun/agent/transaction/traced_method_stack'
module TingYun
  module Agent

    # This is THE location to store thread local information during a transaction
    # Need a new piece of data? Add a method here, NOT a new thread local variable.
    class TransactionState

      # Request data
      attr_accessor :transaction_sample_builder
      attr_reader   :current_transaction, :traced_method_stack, :thrift_return_data
      # Sql Sampler Transaction Data
      attr_accessor :sql_sampler_transaction_data,
                    :client_transaction_id,
                    :client_tingyun_id_secret,
                    :client_req_id,
                    :sql_duration,
                    :external_duration,
                    :web_duration,
                    :queue_duration,
                    :rds_duration,
                    :mc_duration,
                    :mon_duration







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
        @sql_duration = 0
        @external_duration = 0
        @web_duration = 0
        @queue_duration = 0
        @rds_duration = 0
        @mc_duration = 0
        @mon_duration = 0
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

      def init_sql_transaction(obj)
        @sql_sampler_transaction_data = obj
      end

      def set_thrift_return_data(data)
        @thrift_return_data = data
      end


    end
  end
end
