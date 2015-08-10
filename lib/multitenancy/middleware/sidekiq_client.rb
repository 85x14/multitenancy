module Multitenancy::Middleware
  class SidekiqClient
    def call(worker_class, job, queue, redis_pool)
      unless Multitenancy.current_tenant.nil?
        job['tenant_id'] = Multitenancy.current_tenant.tenant_id
        job['sub_tenant_id'] = Multitenancy.current_tenant.sub_tenant_id
      end

      yield
    end
  end
end
