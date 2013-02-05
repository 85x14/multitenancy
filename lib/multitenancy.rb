require "active_record"
require "active_model"
require "multitenancy/version"
require "multitenancy/active_record/switch_db"
require "multitenancy/tenant"
require "multitenancy/rack/filter"
require "multitenancy/model_extensions"
require "multitenancy/rest_client/rest_client.rb"

module Multitenancy
  
  @@tenant_header = 'X_TENANT_ID'
  @@sub_tenant_header = 'X_SUB_TENANT_ID'
  @@append_headers_to_rest_calls = true
  @@logger = (logger rescue nil) || Logger.new(STDOUT)
  @@db_config_prefix = ''
  @@db_config_suffix = '_development'
  @@db_type = :shared # or :dedicated

  class << self
    def init(config)
      @@tenant_header = config[:tenant_header]
      @@sub_tenant_header = config[:sub_tenant_header]
      @@logger = config[:logger] if config[:logger]
      @@append_headers_to_rest_calls = config[:append_headers_to_rest_calls] unless config[:append_headers_to_rest_calls].nil?
      @@db_config_prefix = config[:db_config_prefix] unless config[:db_config_prefix].nil?
      @@db_config_suffix = config[:db_config_suffix] unless config[:db_config_suffix].nil?
      @@db_type = (config[:db_type].nil? || ![:shared, :dedicated].include?(config[:db_type])) ? :shared : config[:db_type] 
    end
    
    def db_type
      @@db_type
    end
    
    def logger
      @@logger
    end
  
    def tenant_header
      @@tenant_header
    end
    
    def sub_tenant_header
      @@sub_tenant_header
    end
    
    def append_headers_to_rest_calls?
      @@append_headers_to_rest_calls
    end
    
    def with_tenant(tenant, &block)
      self.logger.debug "Executing the block with the tenant - #{tenant}"
      if block.nil?
        raise ArgumentError, "block required"
      end
      old_tenant = self.current_tenant
      self.current_tenant = tenant
      begin
        if db_type == :shared
          return block.call
        else
          return ActiveRecord::Base.switch_db("#{@@db_config_prefix}#{tenant.tenant_id}#{@@db_config_suffix}".to_sym, &block)
        end
      ensure
        self.current_tenant = old_tenant
      end
    end
    
    def current_tenant=(tenant)
      self.logger.debug "Setting the current tenant to - #{tenant}"
      Thread.current[:tenant] = tenant
    end
    
    def current_tenant
      Thread.current[:tenant]
    end
  end
end

if defined?(ActiveRecord::Base)
  ActiveRecord::Base.send(:include, Multitenancy::ModelExtensions)
end
