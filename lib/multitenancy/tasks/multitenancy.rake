require "multitenancy"

namespace :multitenancy do
  desc "Add tenant database"
  task :add_tenant_db, [:tenant_id, :base_db_config] => [:environment] do |t, args|
    tenant_id = args[:tenant_id] || raise("Must provide a tenant id")
    base_db_config = args[:base_db_config] || Multitenancy.db_config_suffix.gsub(/^_+/,'')
    raise "Base database config #{base_db_config} does not exist" unless ActiveRecord::Base.configurations[base_db_config]

    db_config_name = "#{Multitenancy.db_config_prefix}#{tenant_id}#{Multitenancy.db_config_suffix}"
    raise "Tenant database already exists" if ActiveRecord::Base.configurations[db_config_name]

    config = ActiveRecord::Base.configurations[base_db_config].to_h
    config['database'] = "#{config['database']}_#{tenant_id}"
    File.open(Multitenancy.db_config_filename, 'a') do |f|
      f << { db_config_name => config }.to_yaml.gsub(/^\-\-\-/,'')
    end

    # reload the database configuration
    reloaded_config = YAML.load_file(Multitenancy.db_config_filename)
    ActiveRecord::Base.configurations = ActiveRecord::Tasks::DatabaseTasks.database_configuration = reloaded_config

    ActiveRecord::Tasks::DatabaseTasks.create(reloaded_config[db_config_name])
    ActiveRecord::Tasks::DatabaseTasks.load_schema_for(db_config_name)
  end

  task :parallel_migrate, [:base_db_config] => [:environment] do |t, args|
    base_db_config = args[:base_db_config] || Multitenancy.db_config_suffix.gsub(/^_+/,'')

    # calculate migration paths based on the base db configuration
    ActiveRecord::Base.switch_db(base_db_config)
    migration_paths = Multitenancy::Migrator.migrations_paths

    # find all tenant dbs with that match the suffix
    tenant_dbs = [base_db_config]
    unless Multitenancy.db_type == :shared
      ActiveRecord::Base.configurations.each do |key, val|
        if Multitenancy.db_config_suffix && key =~ /(.+)#{Multitenancy.db_config_suffix}$/
          tenant_dbs << key
        end
      end
    end

    # ensure all tenant dbs are in sync
    last_base_migration = Multitenancy::Migrator.current_version
    tenant_dbs.each do |tenant_db_config|
      ActiveRecord::Base.switch_db(tenant_db_config)
      if Multitenancy::Migrator.current_version != last_base_migration
        raise "Tenant databases are out of synch. Please run a serial migration instead (rake multitenancy:serial_migrate)."
      end
    end

    # run default of :up for all unprocessed migrations
    Multitenancy::Migrator.tenant_dbs = tenant_dbs
    Multitenancy::Migrator.migrate(migration_paths)
  end

  task :serial_migrate, [:base_db_config] => [:environment] do |t, args|
    base_db_config = args[:base_db_config] || Multitenancy.db_config_suffix.gsub(/^_+/,'')

    # calculate migration paths based on the base db configuration
    ActiveRecord::Base.switch_db(base_db_config)
    migration_paths = ActiveRecord::Migrator.migrations_paths

    # find all tenant dbs with that match the suffix
    tenant_dbs = [base_db_config]
    unless Multitenancy.db_type == :shared
      ActiveRecord::Base.configurations.each do |key, val|
        if Multitenancy.db_config_suffix && key =~ /(.+)#{Multitenancy.db_config_suffix}$/
          tenant_dbs << key
        end
      end
    end

    # run default of :up for all unprocessed migrations
    tenant_dbs.each do |db_config|
      ActiveRecord::Base.switch_db(db_config)
      ActiveRecord::Migrator.migrate(ActiveRecord::Migrator.migrations_paths)
    end
  end

  task :migrate_tenant, [:tenant] => [:environment] do |t, args|
    tenant = Tenant.new(args[:tenant])
    Multitenancy.switch_tenant(tenant)
    ActiveRecord::Migrator.migrate(ActiveRecord::Migrator.migrations_paths)
  end
end
