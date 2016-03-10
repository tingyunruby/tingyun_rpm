  # encoding: utf-8
require 'ting_yun/agent/transaction/trace_node'
require 'ting_yun/support/helper'
require 'ting_yun/support/coerce'
module TingYun
  module Agent
    class Transaction
      class Trace

        attr_accessor :node_count, :threshold, :metric_name, :uri, :guid, :attributes, :start_time, :finished, :thread_name

        attr_reader  :root_node

        def initialize(start_time)
          @start_time = start_time
          @node_count = 0
          @root_node = TingYun::Agent::Transaction::TraceNode.new(0.0, "ROOT")
          @prepared = false
          @thread_name = "pid-#{$$}"
        end

        def create_node(time_since_start, metric_name = nil)
          @node_count += 1
          TingYun::Agent::Transaction::TraceNode.new(time_since_start, metric_name)
        end

        def duration
          @root_node.duration
        end

        include TingYun::Support::Coerce

        def action_trace_data
          [
              @start_time,
              request_params,
              custom_params,

          ]
        end

        def trace_tree
          [
              TingYun::Helper.time_to_millis(duration),
              request_params,
              custom_params,
              []
          ]
        end

        def to_collector_array(encoder)
          [
              @start_time.round,
              TingYun::Helper.time_to_millis(duration),
              TingYun::Helper.correctly_encoded(metric_name),
              TingYun::Helper.correctly_encoded(uri),
              encoder.encode(trace_tree),
              "",
              @guid
          ]
        end

        def prepare_to_send!
          return self if @prepared

          @prepared = true
          self
        end

        def custom_params
          {
              :threadName => thread_name,
              :httpStatus => int(@attributes.agent_attributes[:httpResponseCode]),
              :referer    => string(@attributes.agent_attributes[:referer]) || ''
          }
        end

        def request_params
          @attributes.agent_attributes[:request_params]
        end
      end
    end
  end
end
