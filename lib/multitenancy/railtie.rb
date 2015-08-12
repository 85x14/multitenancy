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

          # need the client middleware on the server as well, as
          # the server may load additional requests
          config.client_middleware do |chain|
            chain.add Multitenancy::Middleware::SidekiqClient
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
