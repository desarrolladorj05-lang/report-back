import { Injectable } from "@nestjs/common";
import { ClsService } from "nestjs-cls";

@Injectable()
export class TenancyContextService {
  constructor(private readonly cls: ClsService) {}

  getTenantId(): string | undefined {
    return this.cls.get<string>("tenantId");
  }

  getDbName(): string | undefined {
    return this.cls.get<string>("dbName");
  }

  setTenant(tenantId: string, dbName: string): void {
    this.cls.set("tenantId", tenantId);
    this.cls.set("dbName", dbName);
  }
}
