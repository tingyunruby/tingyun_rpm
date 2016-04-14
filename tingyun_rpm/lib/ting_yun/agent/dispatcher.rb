# encoding: utf-8

module TingYun
  module Agent
    class Dispatcher
      attr_accessor :starting_pid

      def initialize(events, after_forker=TingYun::Agent)
        # We intentionally don't set our pid as started at this point.
        # Startup routines must call mark_started when they consider us set!
        @starting_pid = nil
        @after_forker = after_forker

        if events
          events.subscribe(:start_transaction, &method(:on_transaction))
        end
      end

      def on_transaction(*_)
        return unless needs_restart?

        restart_harvest_thread
      end

      def mark_started(pid = Process.pid)
        @starting_pid = pid
      end

      def needs_restart?(pid = Process.pid)
        @starting_pid != pid
      end

      def restart_harvest_thread
        @after_forker.after_fork(:force_reconnect => true)
      end

    end
  end
end
