import {
  BadRequestException,
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { parse } from "tldts";
import { Repository } from "typeorm";
import { Tenant } from "./tenant.entity";
import { TenancyContextService } from "./tenancy.context";

export interface ResolvedTenant {
  id: string;
  dbName: string;
}

@Injectable()
export class TenantResolverService {
  constructor(
    @InjectRepository(Tenant)
    private readonly tenantRepository: Repository<Tenant>,
    private readonly context: TenancyContextService,
  ) {}

  async resolveForLogin(clientOrigin?: string): Promise<ResolvedTenant> {
    if (process.env.NODE_ENV !== "production") {
      const id = process.env.DEV_TENANT_ID;
      const dbName = process.env.DEV_TENANT_DB;
      if (id && dbName) return this.apply({ id, dbName });
    }

    if (!clientOrigin) {
      throw new BadRequestException(
        "No se pudo identificar el dominio cliente.",
      );
    }

    const parsed = parse(clientOrigin);
    if (!parsed.domain || !parsed.subdomain) {
      throw new UnauthorizedException("Tenant no autorizado.");
    }

    const tenant = await this.tenantRepository.findOne({
      where: {
        domain: parsed.domain,
        subdomain: parsed.subdomain,
        isActive: true,
      },
      select: ["id", "dbName"],
    });

    if (!tenant) throw new UnauthorizedException("Tenant no autorizado.");
    return this.apply(tenant);
  }

  async resolveById(tenantId: string): Promise<ResolvedTenant> {
    const tenant = await this.tenantRepository.findOne({
      where: { id: tenantId, isActive: true },
      select: ["id", "dbName"],
    });
    if (!tenant) {
      throw new UnauthorizedException("Tenant inexistente o inactivo.");
    }
    return this.apply(tenant);
  }

  private apply(tenant: ResolvedTenant): ResolvedTenant {
    this.context.setTenant(tenant.id, tenant.dbName);
    return tenant;
  }
}
