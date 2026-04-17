import { Module } from "@nestjs/common";
import { TenantDataSourceFactory } from "src/config/tenancy/tenant-ds.factory";
import { CashPettyReportRepository } from "./cash-petty-report.repository";
import { CashPettyReportService } from "./cash-petty-report.service";
import { CashPettyReportController } from "./cash-petty-report.controller";

@Module({
  controllers: [CashPettyReportController],
  providers: [
    CashPettyReportRepository,
    CashPettyReportService,
    TenantDataSourceFactory,
  ],
  exports: [CashPettyReportService],
})
export class CashPettyReportModule {}