module Multitenancy
  class Railtie < Rails::Railtie
    initializer "multitenancy.configure_rails_middleware" do |app|
      Multitenancy.db_config_filename = app.root.join('config', 'database.yml')

      Rails.application.middleware.use Multitenancy::Middleware::RailsRequests
    end

    initializer "multitenancy.confifgure_sidekiq_middleware", :after => 'sidekiq' do
      if defined? Sidekiq
        Sidekiq.configure_server do |config|
          config.server_middleware do |chain|
            chain.add Multitenancy::Middleware::SidekiqServer
          end
        end

        Sidekiq.configure_client do |config|
          config.client_middleware do |chain|
            chain.add Multitenancy::Middleware::SidekiqClient
          end
        end
      end
    end

    rake_tasks do
      load "multitenancy/tasks/multitenancy.rake"
    end
  end
end
