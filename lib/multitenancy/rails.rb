module Multitenancy
  class Railtie < Rails::Railtie
    initializer "multitenancy.configure_middleware" do
      Rails.application.middleware.use Multitenancy::Filter
    end
  end
end
