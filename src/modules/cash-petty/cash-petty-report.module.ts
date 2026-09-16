import { Module } from "@nestjs/common";
import { CashPettyReportRepository } from "./cash-petty-report.repository";
import { CashPettyReportService } from "./cash-petty-report.service";
import { CashPettyReportController } from "./cash-petty-report.controller";
import { AuthModule } from "src/auth/auth.module";

@Module({
  imports: [AuthModule],
  controllers: [CashPettyReportController],
  providers: [CashPettyReportRepository, CashPettyReportService],
  exports: [CashPettyReportService],
})
export class CashPettyReportModule {}
