TingYun::Support::LibraryDetection.defer do
  named :bunny

  depends_on do
    defined?(::Bunny::VERSION) && TingYun::Agent.config[:'nbs.mq.enabled']
  end


  executes do
    TingYun::Agent.logger.info 'Installing bunny(for rabbitmq) Instrumentation'
    require 'ting_yun/support/helper'
    require 'ting_yun/instrumentation/support/external_helper'
  end

  executes do
    ::Bunny::Exchange.class_eval do

      if public_method_defined? :publish
        include TingYun::Instrumentation::Support::ExternalHelper
        def publish_with_tingyun(payload, opts = {})
          begin
            state = TingYun::Agent::TransactionState.tl_get
            return publish_without_tingyun(payload, opts) unless state.execution_traced?
            queue_name = opts[:routing_key]
            opts[:headers] = {} unless opts[:headers]
            opts[:headers][:TingyunID] = create_tingyun_id("mq")
            metric_name = "Message RabbitMQ/#{@channel.connection.host}:#{@channel.connection.port}%2F"
            if name.empty?
              metric_name << "Queue%2F#{queue_name}/Produce"
            else
              metric_name << "Exchange%2F#{name}/Produce"
            end

            summary_metrics = TingYun::Agent::Datastore::MetricHelper.metrics_for_message('RabbitMQ', "#{@channel.connection.host}:#{@channel.connection.port}", 'Produce')
            TingYun::Agent::Transaction.wrap(state, metric_name , :RabbitMq, {}, summary_metrics)  do
              TingYun::Agent.record_metric("#{metric_name}%2FByte",payload.bytesize) if payload
              publish_without_tingyun(payload, opts)
            end
          rescue => e
            TingYun::Agent.logger.error("Failed to Bunny publish_with_tingyun : ", e)
            publish_without_tingyun(payload, opts)
          end
        end




        alias_method :publish_without_tingyun, :publish
        alias_method :publish, :publish_with_tingyun
      end

    end

    ::Bunny::Consumer.class_eval do

      if public_method_defined?(:call) && TingYun::Agent.config[:'nbs.mq.conume']

        def call_with_tingyun(*args)
          begin
            headers = args[1]&&args[1][:headers].clone
            tingyun_id_secret = headers["TingyunID"]
            state = TingYun::Agent::TransactionState.tl_get
            metric_name = "#{@channel.connection.host}:#{@channel.connection.port}%2FQueue%2F#{queue_name}/Consume"
            summary_metrics = TingYun::Agent::Datastore::MetricHelper.metrics_for_message('RabbitMQ', "#{@channel.connection.host}:#{@channel.connection.port}", 'Consume')
            TingYun::Agent::Transaction.start(state,:message, { :transaction_name => "WebAction/RabbitMQ/Queue%2F#{queue_name}/Consume"})
            state.save_referring_transaction_info(tingyun_id_secret.split(';')) if cross_app_enabled?(tingyun_id_secret)
            TingYun::Agent::Transaction.wrap(state, "Message RabbitMQ/#{metric_name}" , :RabbitMq, {}, summary_metrics)  do
              TingYun::Agent.record_metric("Message RabbitMQ/#{metric_name}%2FByte",args[2].bytesize) if args[2]
              TingYun::Agent.record_metric("Message RabbitMQ/#{metric_name}%2FWait", TingYun::Helper.time_to_millis(Time.now)-state.externel_time.to_i) rescue nil
              if state.current_transaction
                state.add_custom_params("message.byte",args[2].bytesize)
                state.add_custom_params("message.wait",TingYun::Helper.time_to_millis(Time.now)-state.externel_time.to_i)
                state.add_custom_params("message.routingkey",queue_name)
                headers.delete("TingyunID")
                state.merge_request_parameters(headers)
              end
              call_without_tingyun(*args)
              state.current_transaction.attributes.add_agent_attribute(:entryTrace, build_payload(state)) if state.same_account?
            end
          rescue => e
            TingYun::Agent.logger.error("Failed to Bunny call_with_tingyun : ", e)
            call_without_tingyun(*args)
          ensure
            TingYun::Agent::Transaction.stop(state, Time.now, summary_metrics)
          end

        end
        alias_method :call_without_tingyun, :call
        alias_method :call, :call_with_tingyun

      end

      def cross_app_enabled?(tingyun_id_secret)
        tingyun_id_secret && ::TingYun::Agent.config[:tingyunIdSecret]
      end

      def build_payload(state)
        timings = state.timings
        payload = {
            :applicationId => TingYun::Agent.config[:tingyunIdSecret].split('|')[1],
            :transactionId => state.client_transaction_id,
            :externalId => state.extenel_req_id,
            :time => {
                :duration => timings.app_time_in_millis,
                :qu => timings.queue_time_in_millis,
                :db => timings.sql_duration,
                :ex => timings.external_duration,
                :rds => timings.rds_duration,
                :mc => timings.mc_duration,
                :mon => timings.mon_duration,
                :code => timings.app_execute_duration
            }
        }
        payload
      end
    end

    ::Bunny::Channel.class_eval do
      if public_method_defined?(:basic_get)&& TingYun::Agent.config[:'nbs.mq.conume']
        def basic_get_with_tingyun(*args)
          begin
            state = TingYun::Agent::TransactionState.tl_get
            metric_name = "#{@connection.host}:#{@connection.port}%2FQueue%2F#{args[0]}/Consume"
            summary_metrics = TingYun::Agent::Datastore::MetricHelper.metrics_for_message('RabbitMQ', "#{connection.host}:#{connection.port}", 'Consume')
            TingYun::Agent::Transaction.wrap(state, "Message RabbitMQ/#{metric_name}" , :RabbitMq, {}, summary_metrics)  do
              basic_get_without_tingyun(*args)
            end
          rescue =>e
            TingYun::Agent.logger.error("Failed to Bunny basic_get_with_tingyun : ", e)
            basic_get_without_tingyun(*args)
          ensure
            TingYun::Agent::Transaction.stop(state, Time.now, summary_metrics)
          end
        end

        alias_method :basic_get_without_tingyun, :basic_get
        alias_method :basic_get, :basic_get_with_tingyun
      end
    end
  end

end