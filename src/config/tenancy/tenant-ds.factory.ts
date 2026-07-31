import { Injectable } from "@nestjs/common";
import { DataSource } from "typeorm";
import { TenantConnectionManager } from "./tenant-connection-manager.service";
import { TenancyContextService } from "./tenancy.context";

@Injectable()
export class TenantDataSourceFactory {
  constructor(
    private readonly context: TenancyContextService,
    private readonly connections: TenantConnectionManager,
  ) {}

  async get(): Promise<DataSource> {
    const dbName = this.context.getDbName();
    if (!dbName) {
      throw new Error("No existe un tenant resuelto para la solicitud.");
    }
    return this.connections.get(dbName);
  }
}
