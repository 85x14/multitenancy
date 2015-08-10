module Multitenancy::Middleware

  class RailsRequests
    def initialize(app)
      @app = app
    end
    
    def call(env)
      tenant = Multitenancy::Tenant.new tenant_id(env), sub_tenant_id(env)
      if exclude_request?(env)
        @app.call env
      else
        Multitenancy.with_tenant tenant do
          @app.call env
        end
      end
    rescue  ActiveRecord::AdapterNotFound
      [
        404,
        { 'Content-Type'  => 'text/html' },
        File.open('public/404.html', File::RDONLY)
      ]
    end
    
    private
    def tenant_id(env)
      # rack converts X_FOO to HTTP_X_FOO
      id = env["HTTP_#{Multitenancy.tenant_header}"]
      if Multitenancy.tenant_header_regexp.blank?
        id
      else
        match = Multitenancy.tenant_header_regexp.match(id)
        match ? match[0] : id
      end
    end

    def sub_tenant_id(env)
      id = env["HTTP_#{Multitenancy.sub_tenant_header}"]
      if Multitenancy.sub_tenant_header_regexp.blank?
        id
      else
        match = Multitenancy.sub_tenant_header_regexp.match(id)
        match ? match[0] : id
      end
    end

    def exclude_request?(env)
      Multitenancy.exclude_paths.include? env['PATH_INFO']
    end
  end
end
