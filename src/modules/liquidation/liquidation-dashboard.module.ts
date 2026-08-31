import { Module } from "@nestjs/common";
import { LiquidationDashboardController } from "./liquidation-dashboard.controller";
import { LiquidationDashboardRepository } from "./liquidation-dashboard.repository";
import { LiquidationDashboardService } from "./liquidation-dashboard.service";

@Module({
  controllers: [LiquidationDashboardController],
  providers: [LiquidationDashboardRepository, LiquidationDashboardService],
})
export class LiquidationDashboardModule {}
