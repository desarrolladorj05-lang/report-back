import { Module } from "@nestjs/common";
import { LiquidationDashboardController } from "./liquidation-dashboard.controller";
import { LiquidationDashboardRepository } from "./liquidation-dashboard.repository";
import { LiquidationDashboardService } from "./liquidation-dashboard.service";
import { AuthModule } from "src/auth/auth.module";

@Module({
  imports: [AuthModule],
  controllers: [LiquidationDashboardController],
  providers: [LiquidationDashboardRepository, LiquidationDashboardService],
})
export class LiquidationDashboardModule {}
