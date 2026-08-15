import { Global, Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { ClsModule } from "nestjs-cls";
import { TenantConnectionManager } from "./tenant-connection-manager.service";
import { TenantDataSourceFactory } from "./tenant-ds.factory";
import { TenantResolverService } from "./tenant-resolver.service";
import { Tenant } from "./tenant.entity";
import { TenantUrl } from "./tenant-url.entity";
import { TenancyContextService } from "./tenancy.context";

@Global()
@Module({
  imports: [
    ClsModule.forRoot({
      global: true,
      middleware: { mount: true },
    }),
    TypeOrmModule.forFeature([Tenant, TenantUrl]),
  ],
  providers: [
    TenancyContextService,
    TenantResolverService,
    TenantConnectionManager,
    TenantDataSourceFactory,
  ],
  exports: [
    TenancyContextService,
    TenantResolverService,
    TenantDataSourceFactory,
  ],
})
export class TenancyModule {}
