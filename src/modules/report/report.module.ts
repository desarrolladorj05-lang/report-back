import { Module } from "@nestjs/common";
import { ReportController } from "./report.controller";
import { ReportService } from "./report.service";
import { ReportRepository } from "./report.repository";
import { TenantDataSourceFactory } from "../../config/tenancy/tenant-ds.factory";

@Module({
  controllers: [ReportController],
  providers: [ReportService, ReportRepository, TenantDataSourceFactory],
  exports: [ReportService],
})
export class ReportModule {}
