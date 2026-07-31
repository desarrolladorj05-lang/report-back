import { Module } from "@nestjs/common";
import { SalesReportController } from "./sales-report.controller";
import { SalesReportRepository } from "./sales-report.repository";
import { SalesReportService } from "./sales-report.service";

@Module({
  controllers: [SalesReportController],
  providers: [SalesReportRepository, SalesReportService],
  exports: [SalesReportService],
})
export class SaleReportModule {}
