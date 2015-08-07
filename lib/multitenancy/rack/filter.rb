module Multitenancy
  
  class Filter
    
    def initialize(app)
      @app = app
    end
    
    def call(env)
      tenant = Tenant.new tenant_id, sub_tenant_id
      Multitenancy.with_tenant tenant do
        @app.call env
      end
    end
    
    private
    def tenant_id
      # rack converts X_FOO to HTTP_X_FOO
      id = env["HTTP_#{Multitenancy.tenant_header}"]
      if Multitenancy.tenant_header_regexp.blank?
        id
      else
        match = Multitenancy.tenant_header_regexp.match(id)
        match ? match[0] : id
      end
    end

    def subtenant_id
      id = env["HTTP_#{Multitenancy.sub_tenant_header}"]
      if Multitenancy.sub_tenant_header_regexp.blank?
        id
      else
        match = Multitenancy.sub_tenant_header_regexp.match(id)
        match ? match[0] : id
      end
    end
  end
end
