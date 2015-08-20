class ActiveRecord::Base
  class << self
   
    @@connection_handlers ||= {}
   
    def connection_handler_with_multi_db_support(spec_symbol = nil)
      return @@connection_handlers[spec_symbol] if spec_symbol
      if Thread.current[:current_db]
        @@connection_handlers[Thread.current[:current_db]] ||= ActiveRecord::ConnectionAdapters::ConnectionHandler.new
      else
        connection_handler_without_multi_db_support
      end
    end
    
    alias_method :connection_handler_without_multi_db_support, :connection_handler      
    alias_method :connection_handler, :connection_handler_with_multi_db_support

    def switch_db(db)
      Thread.current[:current_db] = db

      unless ActiveRecord::Base.connection_handler.retrieve_connection_pool(ActiveRecord::Base)
        # if the database config doesn't exist, try to reload the db config in case a tenant has been added on the fly
        db_config = ActiveRecord::Base.configurations[db.to_s]
        if db_config.nil?
          ActiveRecord::Base.configurations = YAML.load_file(Multitenancy.db_config_filename).with_indifferent_access
          db_config = ActiveRecord::Base.configurations[db.to_s]

          if db_config.nil?
            err_msg = "#{db} database configuration does not exist"
            Multitenancy.logger.warn err_msg
            raise ActiveRecord::AdapterNotFound, err_msg
          end
        end

        ActiveRecord::Base.establish_connection(db_config)
      end
    end

    def with_db(db, &block)
      switch_db(db)
      yield
    ensure
      ActiveRecord::Base.connection_handler.clear_active_connections! rescue puts "supressing error while clearing connections - #{$!.inspect}"
      Thread.current[:current_db] = nil
    end
  end
end
