module Multitenancy::Middleware
  class SidekiqServer
    def call(worker, job, queue)
      if job['tenant_id']
        tenant = Multitenancy::Tenant.new(job['tenant_id'], job['sub_tenant_id'])
        Multitenancy.with_tenant(tenant) do
          yield
        end
      else
        yield
      end
    end
  end
end
