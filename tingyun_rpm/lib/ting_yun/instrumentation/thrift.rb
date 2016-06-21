# encoding: utf-8
require 'ting_yun/support/helper'
require 'ting_yun/agent'

module TingYun
  module Instrumentation
    module ThriftHelper
      def operator result_klass
        namespaces = result_klass.to_s.split('::')
        operator_name = namespaces[0].downcase
        if namespaces.last =~ /_result/
          operator_name = "#{operator_name}.#{namespaces.last.sub('_result', '').downcase}"
        end
        operator_name
      end

      def operations
        @operations ||= {}
      end

      def started_time_and_node(operate)
        _op_ = operations.delete(operate)
        time = (_op_ && _op_[:started_time]) or Time.now.to_f
        node = _op_ && _op_[:node]
        [time, node]
      end


      def tingyun_socket
        @iprot.instance_variable_get("@trans").instance_variable_get("@transport")
      end

      def tingyun_host
        @tingyun_host ||= tingyun_socket.instance_variable_get("@host") rescue nil
      end

      def tingyun_port
        @tingyun_port  ||= tingyun_socket.instance_variable_get("@port") rescue nil
      end

      def metrics operate
        metrics = if tingyun_host.nil?
                    ["External/thrift/#{operate}"]
                  else
                    ["External/thrift:#{tingyun_host}:#{tingyun_port}/#{operate}"]
                  end
        metrics << "External/NULL/ALL"

        if TingYun::Agent::Transaction.recording_web_transaction?
          metrics << "External/NULL/AllWeb"
        else
          metrics << "External/NULL/AllBackground"
        end
        state = TingYun::Agent::TransactionState.tl_get

        my_data = state.thrift_return_data


        if my_data
          uri = "thrift:#{tingyun_host}:#{tingyun_port}/#{operate}"
          metrics << "cross_app;#{my_data["id"]};#{my_data["action"]};#{uri}"
        end
        return metrics

      end
    end
  end
end




TingYun::Support::LibraryDetection.defer do
  named :thrift

  depends_on do
    defined?(::Thrift) && defined?(::Thrift::Client) && defined?(::Thrift::BaseProtocol)
  end


  executes do
    TingYun::Agent.logger.info 'Installing Thrift Instrumentation'
    require 'ting_yun/support/serialize/json_wrapper'
  end

  executes do
    ::Thrift::Processor.module_eval do



      def same_account?(state)
        server_info = TingYun::Agent.config[:tingyunIdSecret].split('|')
        client_info = (state.client_tingyun_id_secret || '').split('|')
        if !server_info[0].nil? && server_info[0] == client_info[0] && !server_info[0].empty?
          return true
        else
          return false
        end
      end
      def write_result_with_tingyun(result, oprot, name, seqid)
        state = TingYun::Agent::TransactionState.tl_get
        oprot.write_message_begin(name, ::Thrift::MessageTypes::REPLY, seqid)

        if state.execution_traced? && same_account?(state)

          class_name = "WebAction/thrift/#{self.class.to_s.split('::').first.downcase}.#{name}"
          ::TingYun::Agent::Transaction.wrap(state, class_name, :thrift) do
            data = TingYun::Support::Serialize::JSONWrapper.dump("TingyunTxData" => build_payload(state))
            oprot.write_field_begin("TingyunField", 11, 6)
            oprot.write_string(data)
            oprot.write_field_end
            write_result_without_tingyun(result, oprot, name, seqid)
            state.current_transaction.add_agent_attribute(:httpStatus, 200)
          end
        else
          write_result_without_tingyun(result, oprot, name, seqid)
        end
      end

      def write_error_with_tingyun(err, oprot, name, seqid)
        p 'write_error'
        state = TingYun::Agent::TransactionState.tl_get
        oprot.write_message_begin(name, ::Thrift::MessageTypes::EXCEPTION, seqid)

        if state.execution_traced? && same_account?(state)

          class_name = "WebAction/thrift/#{self.class.to_s.split('::').first.downcase}.#{name}"
          ::TingYun::Agent::Transaction.wrap(state, class_name, :thrift) do
            data = TingYun::Support::Serialize::JSONWrapper.dump("TingyunTxData" => build_payload(state))
            oprot.write_field_begin("TingyunField", 11, 6)
            oprot.write_string(data)
            oprot.write_field_end
            write_result_without_tingyun(err, oprot, name, seqid)
            p 'write_error end'
            state.current_transaction.add_agent_attribute(:httpStatus, 500)
          end
        else
          write_result_without_tingyun(error, oprot, name, seqid)
        end
      end


      def build_payload(state)
        state.web_duration = TingYun::Helper.time_to_millis(Time.now - state.thrift_start_time)
        payload = {
            :id => TingYun::Agent.config[:tingyunIdSecret].split('|')[1],
            :action => state.current_transaction.best_name,
            :trId => state.transaction_sample_builder.trace.guid,
            :time => {
                :duration => state.web_duration,
                :qu => state.queue_duration,
                :db => state.sql_duration,
                :ex => state.external_duration,
                :rds => state.rds_duration,
                :mc => state.mc_duration,
                :mon => state.mon_duration,
                :code => execute_duration(state)
            }
        }
        payload[:tr] = 1 if slow_action_tracer?(state)
        payload[:r] = state.client_req_id unless state.client_req_id.nil?
        payload
      end

      def slow_action_tracer?(state)
        if state.web_duration > TingYun::Agent.config[:'nbs.action_tracer.action_threshold']
          return true
        else
          return false
        end
      end

      def write_result_without_tingyun(result, oprot, name, seqid)
        result.write(oprot)
        oprot.write_message_end
        oprot.trans.flush
      end

      def execute_duration(state)
        state.web_duration - state.queue_duration - state.sql_duration - state.external_duration - state.rds_duration - state.mc_duration - state.mon_duration
      end

      alias :write_result  :write_result_with_tingyun
      alias :write_error  :write_error_with_tingyun
      # alias :write_result_without_tingyun  :write_result
    end

    ::Thrift::BaseProtocol.class_eval do

      def skip_with_tingyun(type)

        data = skip_without_tingyun(type)
        state = TingYun::Agent::TransactionState.tl_get
        if data.is_a? ::String
          if data.include?("TingyunTxData")

            my_data = TingYun::Support::Serialize::JSONWrapper.load data.gsub("'",'"')

            state.thrift_return_data = my_data["TingyunTxData"]

            transaction_sampler = ::TingYun::Agent.instance.transaction_sampler
            transaction_sampler.tl_builder.current_node[:txId] = state.request_guid
            transaction_sampler.tl_builder.current_node[:txData] = my_data["TingyunTxData"]
          elsif data.include?("TingyunID")
            state.thrift_start_time = Time.now
            my_data = TingYun::Support::Serialize::JSONWrapper.load data.gsub("'",'"')
            save_referring_transaction_info(state, my_data)
          end
        end
      end

      def save_referring_transaction_info(state,data)

        info = data["TingyunID"].split(';')
        tingyun_id_secret = info[0]
        client_transaction_id = info.find do |e|
          e.match(/x=/)
        end.split('=')[1] rescue nil
        client_req_id = info.find do |e|
          e.match(/r=/)
        end.split('=')[1] rescue nil

        state.client_tingyun_id_secret = tingyun_id_secret
        state.client_transaction_id = client_transaction_id
        state.client_req_id = client_req_id
      end

      alias :skip_without_tingyun :skip
      alias :skip  :skip_with_tingyun
    end

    ::Thrift::Client.module_eval do

      include TingYun::Instrumentation::ThriftHelper

      def send_message_args_with_tingyun(args_class, args = {})
        state = TingYun::Agent::TransactionState.tl_get
        return  unless state.execution_traced?

        cross_app_id  = TingYun::Agent.config[:tingyunIdSecret] or
            raise TingYun::Agent::CrossAppTracing::Error, "no tingyunIdSecret configured"
        txn_guid = state.request_guid
        tingyun_id = "#{cross_app_id};c=1;x=#{txn_guid}"

        data = TingYun::Support::Serialize::JSONWrapper.dump("TingyunID" => tingyun_id)
        @oprot.write_field_begin("TingyunField", 11, 6)
        @oprot.write_string(data)
        @oprot.write_field_end
        send_message_args_without_tingyun(args_class, args)
      end

      alias :send_message_args_without_tingyun :send_message_args
      alias :send_message_args  :send_message_args_with_tingyun

      def send_message_with_tingyun(name, args_class, args = {})

        tag = "#{args_class.to_s.split('::').first.downcase}.#{name}"
        t0 = Time.now.to_f
        operations[tag] = {:started_time => t0}
        state = TingYun::Agent::TransactionState.tl_get
        return  unless state.execution_traced?
        stack = state.traced_method_stack
        node = stack.push_frame(state,:thrift,t0)
        operations[tag][:node] = node

        send_message_without_tingyun(name, args_class, args)
      end

      alias :send_message_without_tingyun :send_message
      alias :send_message  :send_message_with_tingyun



      def receive_message_with_tingyun(result_klass)
        state = TingYun::Agent::TransactionState.tl_get

        t1 = Time.now.to_f

        operate = operator(result_klass)
        t0, node =  started_time_and_node(operate)


        result = receive_message_without_tingyun(result_klass)

        base, *other_metrics = metrics(operate)
        duration = TingYun::Helper.time_to_millis(t1 - t0)

        if node
          node.name = base
          transaction_sampler = ::TingYun::Agent.instance.transaction_sampler
          transaction_sampler.add_node_info(:uri => "thrift:#{tingyun_host}:#{tingyun_port}/#{operate}")
          stack = state.traced_method_stack
          stack.pop_frame(state, node, "External/#{operate}", t1)
        end

        TingYun::Agent.instance.stats_engine.tl_record_scoped_and_unscoped_metrics(
            base, other_metrics, duration
        )
        result
      end

      alias :receive_message_without_tingyun :receive_message
      alias :receive_message :receive_message_with_tingyun
    end
  end

end