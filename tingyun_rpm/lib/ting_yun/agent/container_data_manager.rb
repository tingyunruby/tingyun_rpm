# encoding: utf-8
require 'ting_yun/support/exception'
require 'ting_yun/agent/collector/stats_engine'

module TingYun
  module Agent
    module ContainerDataManager

      attr_reader :stats_engine

      def drop_buffered_data
        @stats_engine.reset!
      end

      # private

      def init_containers
        @stats_engine = TingYun::Agent::Collector::StatsEngine.new
      end

      def container_for_endpoint(endpoint)
        case endpoint
          when :metric_data             then @stats_engine
            # type code here
        end
      end

      def transmit_data
        now = Time.now
        ::TingYun::Agent.logger.debug('Sending data to Ting Yun Service')

        @service.session do
          harvest_and_send_timeslice_data
        end
      end

      def harvest_and_send_timeslice_data
        harvest_and_send_from_container(@stats_engine, :metric_data)
      end


      # Harvests data from the given container, sends it to the named endpoint
      # on the service, and automatically merges back in upon a recoverable
      # failure.
      #
      # The given container should respond to:
      #
      #  #harvest!
      #    returns an enumerable collection of data items to be sent to the
      #    collector.
      #
      #  #reset!
      #    drop any stored data and reset to a clean state.
      #
      #  #merge!(items)
      #    merge the given items back into the internal buffer of the
      #    container, so that they may be harvested again later.
      #
      def harvest_and_send_from_container(container,endpoint)
        items = harvest_from_container(container, endpoint)
        send_data_to_endpoint(endpoint, items, container) unless items.empty?
      end

      def harvest_from_container(container, endpoint)
        items =[]
        begin
          items = container.harvest!
        rescue => e
          TingYun::Agent.logger.error("Failed to harvest #{endpoint} data, resetting. Error: ", e)
          container.reset!
        end
        items
      end

      def send_data_to_endpoint(endpoint, items, container)
        TingYun::Agent.logger.debug("Sending #{items.size} items to #{endpoint}")
        begin
          @service.send(endpoint, items)
        rescue ::TingYun::Support::Exception::ForceRestartException, ::TingYun::Support::Exception::ForceDisconnectException
          raise
        rescue ::TingYun::Support::Exception::SerializationError => e
          TingYun::Agent.logger.warn("Failed to serialize data for #{endpoint}, discarding. Error: ", e)
        rescue ::TingYun::Support::Exception::UnrecoverableServerException => e
          TingYun::Agent.logger.warn("#{endpoint} data was rejected by remote service, discarding. Error: ", e)
        rescue ::TingYun::Support::Exception::ServerConnectionException => e
          TingYun::Agent.logger.debug("Unable to send #{endpoint} data, will try again later. Error: ", e)
          container.merge!(items)
        rescue => e
          TingYun::Agent.logger.info("Unable to send #{endpoint} data, will try again later. Error: ", e)
          container.merge!(items)
        end
      end

    end
  end
end
