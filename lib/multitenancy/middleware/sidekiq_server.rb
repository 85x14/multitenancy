module Multitenancy::Middleware
  class SidekiqServer
    def call(worker, job, queue)
      tenant = Multitenancy::Tenant.new(job[:tenant_id], job[:sub_tenant_id])
      Multitenancy.with_tenant(tenant) do
        yield
      end
    end
  end
end
