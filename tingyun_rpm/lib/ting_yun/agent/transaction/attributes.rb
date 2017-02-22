# encoding: utf-8

module TingYun
  module Agent
    class Transaction
      class Attributes

        attr_accessor :agent_attributes, :request_params
        def initialize
          @agent_attributes  = {:httpStatus => 0} #defaul value
          @request_params = {}
        end

        # no longer to care about the value if nil or not
        def add_agent_attribute(key, value)
          @agent_attributes[key] = value
        end

        def merge_request_parameters(hash)
          @request_params.merge!(hash) if hash
        end

      end
    end
  end
end
