# encoding: utf-8
# This file is distributed under Ting Yun's license terms.
require 'ting_yun/configuration/default_source'
require 'ting_yun/configuration/environment_source'
require 'ting_yun/configuration/yaml_source'
require 'ting_yun/configuration/server_source'
require 'ting_yun/configuration/manual_source'


module TingYun
  module Configuration
    class Manager

      def initialize
        reset_to_defaults
      end

      def [](key)
        @cache[key]
      end

      def has_key?(key)
        @cache.has_key?(key)
      end

      def keys
        @cache.keys
      end

      def app_names
        case TingYun::Agent.config[:app_name]
          when Array then
            TingYun::Agent.config[:app_name]
          when String then
            TingYun::Agent.config[:app_name].split(';')
          else
            []
        end
      end

      def reset_to_defaults
        @default_source = DefaultSource.new
        @environment_source = EnvironmentSource.new
        @yaml_source = nil
        @server_source  = nil
        @manual_source = nil
        # @callbacks = Hash.new {|hash,key| hash[key] =[]}#存放需要merge本地和服务端配置的info'

        @configs_for_testing = []

        reset_cache
      end

      def reset_cache
        @cache = Hash.new { |hash, key| hash[key] = self.fetch(key) }
      end

      def fetch(key)
        config_stack.each do |config|
          next unless config
          accessor = key.to_sym

          if config.has_key?(accessor)
            return evaluated = evaluate_procs(config[accessor]) #if it's proc
          end
        end
        nil
      end

      def evaluate_procs(value)
        if value.respond_to?(:call)
          instance_eval(&value)
        else
          value
        end
      end

      def add_config_for_testing(source, level=0)
        raise 'Invalid config type for testing' unless [Hash, DottedHash].include?(source.class)
        @configs_for_testing << [source.freeze, level]
        reset_cache
        log_config(:add, source)
      end

      def remove_config_type(sym)
        source = case sym
                   when :environment then   @environment_source
                   when :server      then   @server_source
                   when :manual      then   @manual_source
                   when :yaml        then   @yaml_source
                   when :default     then   @default_source
                 end
        remove_config(source)
      end


      def remove_config(source)
        case source
          when YamlSource         then  @yaml_source          = nil
          when DefaultSource      then  @default_source       = nil
          when EnvironmentSource  then  @environment_source   = nil
          when ManualSource       then  @manual_source        = nil
          when ServerSource       then  @server_source        = nil
          else
            @configs_for_testing.delete_if { |src, lvl| src == source }
        end

        reset_cache

        #invoke_callbacks(:remove,source)

        log_config(:remove, source)

      end

      def replace_or_add_config(source)
        source.freeze
        #invoke_callbacks(:add,source)

        case source
          when YamlSource        then   @yaml_source          = source
          when DefaultSource     then   @default_source       = source
          when EnvironmentSource then   @environment_source   = source
          when ServerSource      then   @server_source        = source
          when ManualSource      then   @manual_source        = source
          else
            TingYun::Agent.logger.warn("Invalid config format; config will be ignored: #{source}")
        end
        reset_cache

      end

      def invoke_callbacks(direction, source)
        return unless source
        source.keys.each do |key|
          if @cache[key]!= source[key]
            @callbacks[key].each do |proc|
              if direction == :add
                proc.call(source[key])
              else
                proc.call(@cache[key])
              end
            end
          end
        end
      end

      def source(key)
        config_stack.each do |config|
          if config.respond_to?(key.to_sym) || config.has_key?(key.to_sym)
            return config
          end
        end
      end

      def log_config(direction, source)
        # Just generating this log message (specifically calling
        # flattened.inspect) is expensive enough that we don't want to do it
        # unless we're actually going to be logging the message based on our
        # current log level.
        ::TingYun::Agent.logger.debug do
          "Updating config (#{direction}) from #{source.class}. Results: #{flattened.inspect}"
        end
      end

      def flattened
        config_stack.reverse.inject({}) do |flat, layer|
          thawed_layer = layer.to_hash.dup
          thawed_layer.each do |k, v|
            begin
              thawed_layer[k] = instance_eval(&v) if v.respond_to?(:call)
            rescue => e
              ::TingYun::Agent.logger.debug("#{e.class.name} : #{e.message} - when accessing config key #{k}")
              thawed_layer[k] = nil
            end
            thawed_layer.delete(:config)
          end
          flat.merge(thawed_layer.to_hash)
        end
      end

      def config_classes_for_testing
        config_stack.map(&:class)
      end


      private

      def config_stack
        stack = [@environment_source, @server_source, @manual_source, @yaml_source, @default_source]

        stack.compact!

        @configs_for_testing.each do |config, at_start|
          if at_start
            stack.insert(0, config)
          else
            stack.push(config)
          end
        end

        stack
      end
    end
  end
end