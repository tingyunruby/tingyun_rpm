# encoding: utf-8

require 'ting_yun/agent/transaction/trace'


module TingYun
  module Agent
    class TransactionSampleBuilder
      attr_reader :current_node, :trace

      def initialize(time=Time.now)
        @trace = TingYun::Agent::Transaction::Trace.new(time.to_f)
        @trace_start = time.to_f
      end

      def trace_entry(time)
        if @trace.node_count == 0
          node = @trace.create_node(time.to_f - @trace_start)
          @trace.root_node = node
          @current_node = node
          return @current_node
        end
        if @trace.node_count < node_limit
          node = @trace.create_node(time.to_f - @trace_start)
          @current_node.add_called_node(node)
          @current_node = node

          if @trace.node_count == node_limit
            ::TingYun::Agent.logger.debug("Node limit of #{node_limit} reached, ceasing collection.")
          end
        end
        @current_node
      end

      def trace_exit(metric_name, time)
        @current_node.metric_name = metric_name
        @current_node.end_trace(time.to_f - @trace_start)
        @current_node = @current_node.parent_node
      end

      def finish_trace(time=Time.now.to_f)

        if @trace.finished
          ::TingYun::Agent.logger.error "Unexpected double-finish_trace of Transaction Trace Object: \n#{@trace.to_s}"
          return
        end

        @trace.root_node.end_trace(time - @trace_start)

        @trace.threshold = transaction_trace_threshold
        @trace.finished = true
        @current_node = nil
      end


      def transaction_trace_threshold
        Agent.config[:'nbs.action_tracer.action_threshold']
      end




      def node_limit
        Agent.config[:'transaction_tracer.limit_segments']
      end
    end
  end
end
