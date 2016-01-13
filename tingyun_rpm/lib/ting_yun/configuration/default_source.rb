# encoding: utf-8
# This file is distributed under Ting Yun's license terms.


require 'forwardable'
require 'ting_yun/agent'
require 'ting_yun/frameworks'

module TingYun
  module Configuration

    # Helper since default Procs are evaluated in the context of this module
    def self.value_of(key)
      Proc.new do
        TingYun::Agent.config[key]
      end
    end

    class Boolean;
    end

    class DefaultSource
      attr_reader :defaults

      extend Forwardable
      def_delegators :@defaults, :has_key?, :each, :merge, :delete, :keys, :[], :to_hash


      def initialize
        @defaults = default_values
      end

      def self.framework
        Proc.new {
          case
            when defined?(::TingYun::TEST) then
              :test
            when defined?(::Merb) && defined?(::Merb::Plugins) then
              :merb
            when defined?(::Rails::VERSION)
              case Rails::VERSION::MAJOR
                when 0..2
                  :rails
                when 3
                  :rails3
                when 4
                  :rails4
                else
                  ::TingYun::Agent.logger.error "Detected unsupported Rails version #{Rails::VERSION::STRING}"
              end
            when defined?(::Sinatra) && defined?(::Sinatra::Base) then
              :sinatra
            when defined?(::TingYun::IA) then
              :external
            else
              :ruby
          end
        }
      end

      def self.config_path
        Proc.new {
          found_path = TingYun::Agent.config[:config_search_paths].detect do |file|
            File.expand_path(file) if File.exist? file
          end
          found_path || ''
        }
      end


      def default_values
        result = {}
        ::TingYun::Configuration::DEFAULTS.each do |key, value|
          result[key] = value[:default]
        end
        result
      end

      def self.auto_app_naming
        Proc.new { true }
      end

      def self.dispatcher
        Proc.new { ::TingYun::Frameworks.framework.local_env.discovered_dispatcher }
      end


      def self.audit_log_path
        Proc.new {
          File.join(TingYun::Agent.config[:log_file_path], 'newrelic_audit.log')
        }
      end

      # On Rubies with string encodings support (1.9.x+), default to always
      # normalize encodings since it's safest and fast. Without that support
      # the conversions are too expensive, so only enable if overridden to.
      def self.normalize_json_string_encodings
        Proc.new { TingYun::Support::LanguageSupport.supports_string_encodings? }
      end


      def self.app_name
        Proc.new { ::TingYun::Frameworks.framework.env }
      end

      def self.port
        Proc.new { TingYun::Agent.config[:ssl] ? 443 : 80 }
      end

      def self.agent_enabled
        Proc.new {
          TingYun::Agent.config[:enabled]
        }
      end
      def self.config_search_paths
        Proc.new {
          paths = [
              File.join("config", "tingyun.yml"),
              File.join("tingyun.yml")
          ]

          if ::TingYun::Frameworks.framework.root
            paths << File.join(::TingYun::Frameworks.framework.root, "config", "tingyun.yml")
            paths << File.join(::TingYun::Frameworks.framework.root, "tingyun.yml")
          end

          if ENV["HOME"]
            paths << File.join(ENV["HOME"], ".tingyun", "tingyun.yml")
            paths << File.join(ENV["HOME"], "tingyun.yml")
          end

          # If we're packaged for warbler, we can tell from GEM_HOME
          if ENV["GEM_HOME"] && ENV["GEM_HOME"].end_with?(".jar!")
            app_name = File.basename(ENV["GEM_HOME"], ".jar!")
            paths << File.join(ENV["GEM_HOME"], app_name, "config", "tingyun.yml")
          end

          paths
        }
      end
    end

    DEFAULTS = {
        :license_key => {
            :default => '',
            :public => true,
            :type => String,
            :allowed_from_server => false,
            :description => 'Your Ting Yun <a href="">license key</a>.'
        },
        :'nbs.agent_enabled' => {
            :default => true,
            :public => true,
            :type => Boolean,
            :allowed_from_server => true,
            :description => 'Enable or disable the agent.'
        },
        :app_name => {
            :default => DefaultSource.app_name,
            :public => true,
            :type => String,
            :allowed_from_server => false,
            :description => 'Semicolon-delimited list of Naming your application.'
        },
        :auto_app_naming => {
            :default => true,
            :public => true,
            :type => Boolean,
            :allowed_from_server => false,
            :description => 'Enable or disable to identify the application name'
        },
        :agent_log_file_path => {
            :default => 'log/',
            :public => true,
            :type => String,
            :allowed_from_server => false,
            :description => 'Specifies a path to the audit log file '
        },
        :agent_log_file_name => {
            :default => 'tingyun_agent.log',
            :public => true,
            :type => String,
            :allowed_from_server => false,
            :description => 'log  filename.'
        },
        :config_search_paths => {
            :default => DefaultSource.config_search_paths,
            :public => false,
            :type => Array,
            :allowed_from_server => false,
            :description => "An array of candidate locations for the agent's configuration file."
        },
        :dispatcher => {
            :default => DefaultSource.dispatcher,
            :public => false,
            :type => Symbol,
            :allowed_from_server => false,
            :description => 'Autodetected application component that reports metrics to Ting YUN.'
        },
        :framework => {
            :default => DefaultSource.framework,
            :public => false,
            :type => Symbol,
            :allowed_from_server => false,
            :description => 'Autodetected application framework used to enable framework-specific functionality.'
        },
        :monitor_mode => {
            :default => true,
            :public => true,
            :type => Boolean,
            :allowed_from_server => false,
            :description => 'Enable or disable the transmission of data to the collector.'
        },
        :audit_mode => {
            :default => false,
            :public => true,
            :type => Boolean,
            :allowed_from_server => false,
            :description => 'Enable or disable to log the transmission-date for developer'
        },
        :agent_log_level => {
            :default => 'info',
            :public => true,
            :type => String,
            :allowed_from_server => false,
            :description => 'Log level for agent logging: fatal, error, warn, info, debug.'
        },
        :proxy_host => {
            :default => nil,
            :allow_nil => true,
            :public => true,
            :type => String,
            :allowed_from_server => false,
            :description => 'Defines a host for communicating with Ting Yun via a proxy server.'
        },
        :proxy_port => {
            :default => 8080,
            :allow_nil => true,
            :public => true,
            :type => Fixnum,
            :allowed_from_server => false,
            :description => 'Defines a port for communicating with Ting Yun via a proxy server.'
        },
        :proxy_user => {
            :default => nil,
            :allow_nil => true,
            :public => true,
            :type => String,
            :allowed_from_server => false,
            :description => 'Defines a user for communicating with Ting Yun via a proxy server.'
        },
        :proxy_password => {
            :default => nil,
            :allow_nil => true,
            :public => true,
            :type => String,
            :allowed_from_server => false,
            :exclude_from_reported_settings => true,
            :description => 'Defines a password for communicating with Ting Yun via a proxy server.'
        },
        :host => {
            :default => 'redirect.networkbench.com',
            :public => false,
            :type => String,
            :allowed_from_server => false,
            :description => "URI for the Ting Yun data collection service."
        },
        :port => {
            :default => DefaultSource.port,
            :allow_nil => true,
            :public => false,
            :type => Fixnum,
            :allowed_from_server => false,
            :description => 'Port for the Ting Yun data collection service.'
        },
        :api_host => {
            :default => 'dc1.networkbench.com',
            :public => false,
            :type => String,
            :allowed_from_server => false,
            :description => 'API host for Ting Yun.'
        },
        :api_port => {
            :default => value_of(:port),
            :public => false,
            :type => Fixnum,
            :allowed_from_server => false,
            :description => 'Port for the New Relic API host.'
        },
        :disable_middleware_instrumentation => {
            :default      => false,
            :public       => true,
            :type         => Boolean,
            :allowed_from_server => false,
            :description  => 'Defines whether the agent will wrap third-party middlewares in instrumentation (regardless of whether they are installed via Rack::Builder or Rails).'
        },
        :disable_rack => {
            :default      => false,
            :public       => true,
            :type         => Boolean,
            :dynamic_name => true,
            :allowed_from_server => false,
            :description  => 'Defines whether the agent will hook into Rack::Builder\'s <code>to_app</code> method to find gems to instrument during application startup.'
        },
        :disable_view_instrumentation => {
            :default => false,
            :public => true,
            :type => Boolean,
            :allowed_from_server => false,
            :description => 'Enable or disable view instrumentation.'
        },
        :keep_retrying => {
            :default => true,
            :public => false,
            :type => Boolean,
            :deprecated => true,
            :allowed_from_server => false,
            :description => 'Enable or disable retrying failed connections to the ting yun data collection service.'
        },
        :force_reconnect => {
            :default => true,
            :public => false,
            :type => Boolean,
            :allowed_from_server => false,
            :description => 'Force a new connection to the server before running the worker loop. Creates a separate agent run and is recorded as a separate instance by the ting yun data collection service.'
        },
        :aggressive_keepalive => {
            :default => true,
            :public => false,
            :type => Boolean,
            :allowed_from_server => false,
            :description => 'If true, attempt to keep the TCP connection to the collector alive between harvests.'
        },
        :keep_alive_timeout => {
            :default => 60,
            :public => false,
            :type => Fixnum,
            :allowed_from_server => false,
            :description => 'Timeout for keep alive on TCP connection to collector if supported by Ruby version. Only used in conjunction when aggressive_keepalive is enabled.'
        },
        :ca_bundle_path => {
            :default => nil,
            :allow_nil => true,
            :public => true,
            :type => String,
            :allowed_from_server => false,
            :description => "Manual override for the path to your local CA bundle. This CA bundle will be used to validate the SSL certificate presented by Ting Yun's data collection service."
        },
        :ssl => {
            :default => true,
            :allow_nil => true,
            :public => true,
            :type => Boolean,
            :allowed_from_server => false,
            :description => 'Enable or disable SSL for transmissions to the Ting Yun'
        },
        :timeout => {
            :default => 2 * 60, # 2 minutes
            :public => true,
            :type => Fixnum,
            :allowed_from_server => false,
            :description => 'Maximum number of seconds to attempt to contact the  collector.'
        },
        :post_size_limit => {
            :default => 2 * 1024 * 1024, # 2MB
            :public => false,
            :type => Fixnum,
            :allowed_from_server => false,
            :description => 'Maximum number of bytes to send to the data collection service.'
        },
        :data_report_period => {
            :default => 60,
            :public => false,
            :type => Fixnum,
            :allowed_from_server => false,
            :description => 'Number of seconds betwixt connections to the Ting Yun data collection service.'
        },
        :'action_tracer.log_sql' => {
            :default => false,
            :public => true,
            :type => Boolean,
            :allowed_from_server => false,
            :description => 'Enable or disable(write into log file) collection of SQL queries.'
        },
        :daemon_debug => {
            :default => false,
            :public => true,
            :type => Boolean,
            :allowed_from_server => true,
            :description => 'Enable or disable(result-json contains key-id) debug mode'
        },
        :urls_captured => {
            :default => '',
            :public => true,
            :type => String,
            :allowed_from_server => false,
            :description => 'Enable or disable Specifies url'
        },
        :auto_action_naming => {
            :default => true,
            :public => true,
            :type => Boolean,
            :allowed_from_server => false,
            :description => 'Enable or disable to use default name '
        },
        :capture_params => {
            :default => false,
            :public => true,
            :type => Boolean,
            :allowed_from_server => false,
            :description => 'Enable or disable the capture of HTTP request parameters to be attached to transaction traces and traced errors.'
        },
        :config_path => {
            :default => DefaultSource.config_path,
            :public => true,
            :type => String,
            :allowed_from_server => false,
            :description => 'Path to <b>tingyun.yml</b>. When omitted the agent will check (in order) <b>config/tingyun.yml</b>, <b>tingyun.yml</b>, <b>$HOME/.tingyun/tingyun.yml</b> and <b>$HOME/tingyun.yml</b>.'
        },
        :ignored_params => {
            :default => '',
            :public => true,
            :type => String,
            :allowed_from_server => false,
            :description => 'Enable or disable Specifies HTTP request parameters '
        },
        :apdex_t => {
            :default => 500,
            :public => true,
            :type => Fixnum,
            :allowed_from_server => true,
            :deprecated => true,
            :description => 'millisecond'
        },
        :"error_collector.enabled" => {
            :default => true,
            :public => true,
            :type => Boolean,
            :allowed_from_server => false,
            :description => 'Enable or disable recording of traced errors and error count metrics.'
        },
        :"error_collector.ignored_status_codes" => {
            :default => '',
            :public => true,
            :type => String,
            :allowed_from_server => false,
            :description => 'Enable or disable Specifies HTTP response code '
        },
        :web_action_uri_params_captured => {
            :default => '',
            :public => true,
            :type => String,
            :allowed_from_server => false,
            :description => 'Enable or disable Specifies WebAction request parameters  '
        },
        :external_url_params_captured => {
            :default => '',
            :public => true,
            :type => String,
            :allowed_from_server => false,
            :description => 'Enable or disable Specifies External  request parameters  '
        },
        :'action_tracer.enabled' => {
            :default => true,
            :public => true,
            :type => Boolean,
            :allowed_from_server => false,
            :description => 'Enable or disable action traces'
        },
        :'action_tracer.action_threshold' => {
            :default => nil,
            :allow_nil => true,
            :public => true,
            :type => Fixnum,
            :allowed_from_server => false,
            :description => 'The agent will collect traces for action that exceed this time threshold (in millisecond). Specify a int value or <code><a href="">apdex_f</a></code>.'
        },
        :'action_tracer.record_sql' => {
            :default => 'obfuscate',
            :public => true,
            :type => String,
            :allowed_from_server => false,
            :description => 'Obfuscation level for SQL queries reported in action trace nodes. Valid options are <code>obfuscated</code>, <code>raw</code>, <code>off</code>.'
        },
        :'action_tracer.slow_sql' => {
            :default => true,
            :public => true,
            :type => Boolean,
            :allowed_from_server => false,
            :description => 'Enable or disable collection of slow SQL queries.'
        },
        :'action_tracer.slow_sql_threshold' => {
            :default => 500,
            :public => true,
            :type => Fixnum,
            :allowed_from_server => false,
            :description => 'The agent will collect traces for slow_sql that exceed this time threshold (in millisecond). Specify a int value or <code><a href="">apdex_f</a></code>.'
        },
        :'action_tracer.explain_enabled' => {
            :default => true,
            :public => true,
            :type => Boolean,
            :allowed_from_server => false,
            :description => 'Enable or disable the collection of explain plans in action traces. This setting will also apply to explain plans in Slow SQL traces if slow_sql.explain_enabled is not set separately.'
        },
        :'action_tracer.explain_threshold' => {
            :default => 500,
            :public => true,
            :type => Fixnum,
            :allowed_from_server => false,
            :description => 'Threshold (in millisecond) above which the agent will collect explain plans. Relevant only when <code><a href="">explain_enabled</a></code> is true.'
        },
        :'action_tracer.stack_trace_threshold' => {
            :default => 500,
            :public => true,
            :type => Fixnum,
            :allowed_from_server => false,
            :description => 'Threshold (in millisecond) above which the agent will collect stack_trace.'
        },
        :'action_tracer.nbsua' => {
            :default => true,
            :public => true,
            :type => Boolean,
            :allowed_from_server => false,
            :description => 'Enable or disable to trace nbs web request'
        },
        :'transaction_tracer.enabled' => {
            :default => false,
            :public => true,
            :type => Boolean,
            :allowed_from_server => false,
            :description => 'Enable or disable transaction traces'
        },
        :'rum.enabled' => {
            :default => false,
            :public => false,
            :type => Boolean,
            :allowed_from_server => false,
            :description => 'Enable or disable page load timing (sometimes referred to as real user monitoring or RUM).'
        },
        :'rum.script' => {
            :default => nil,
            :allow_nil => true,
            :public => false,
            :type => String,
            :allowed_from_server => false,
            :description => 'RUM Script URI'
        },
        :'rum.sample_ratio' => {
            :default => 1,
            :public => true,
            :type => Fixnum,
            :allowed_from_server => false,
            :description => 'RUM per'
        },
        :send_environment_info => {
            :default => true,
            :public => false,
            :type => Boolean,
            :allowed_from_server => false,
            :description => 'Enable or disable transmission of application environment information to the Ting Yun data collection service.'
        },
        :normalize_json_string_encodings => {
            :default => DefaultSource.normalize_json_string_encodings,
            :public => false,
            :type => Boolean,
            :allowed_from_server => false,
            :description => 'Controls whether to normalize string encodings prior to serializing data for the collector to JSON.'
        }

    }.freeze
  end
end