module Multitenancy
  class Migrator < ActiveRecord::Migrator
    cattr_accessor :tenant_dbs

    def execute_migration_in_transaction(migration, direction)
      # if there's an error in the migration, want to abort all threads upon the error (and because we keep all our transactions open
      # and uncommited until all complete, none will commit)
      Thread.abort_on_exception = true

      threads = Migrator.tenant_dbs.map do |tenant_db|
        # use a unique thread for this migration
        Thread.new do
          # switch database connection for this thread
          ActiveRecord::Base.switch_db(tenant_db)

          ddl_transaction(migration) do
            migration.migrate(direction)
            record_version_state_after_migrating(migration.version)
            Thread.stop
          end
        end
      end

      # wait for all threads to sleep (or, if any aborts, all threads fail)
      sleep 0.1 while threads.any?{|t| t.status != "sleep" }

      # wakeup all threads and join them
      threads.each do |thread|
        thread.run
        thread.join
      end
    end
  end
end
