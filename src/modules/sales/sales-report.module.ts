import { Module } from "@nestjs/common";
import { SalesReportController } from "./sales-report.controller";
import { SalesReportRepository } from "./sales-report.repository";
import { SalesReportService } from "./sales-report.service";
import { TenantDataSourceFactory } from "src/config/tenancy/tenant-ds.factory";

@Module({
  controllers: [SalesReportController],
  providers: [
    SalesReportRepository,
    SalesReportService,
    TenantDataSourceFactory,
  ],
  exports: [SalesReportService],
})
export class SaleReportModule {}
