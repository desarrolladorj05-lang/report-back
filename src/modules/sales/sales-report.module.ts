import { Module } from "@nestjs/common";
import { SalesReportController } from "./sales-report.controller";
import { SalesReportRepository } from "./sales-report.repository";
import { SalesReportService } from "./sales-report.service";
import { AuthModule } from "src/auth/auth.module";

@Module({
  imports: [AuthModule],
  controllers: [SalesReportController],
  providers: [SalesReportRepository, SalesReportService],
  exports: [SalesReportService],
})
export class SaleReportModule {}
