import { Module } from "@nestjs/common";
import { ProductStockDashboardController } from "./product-stock-dashboard.controller";
import { ProductStockDashboardRepository } from "./product-stock-dashboard.repository";
import { ProductStockDashboardService } from "./product-stock-dashboard.service";
import { AuthModule } from "src/auth/auth.module";

@Module({
  imports: [AuthModule],
  controllers: [ProductStockDashboardController],
  providers: [ProductStockDashboardRepository, ProductStockDashboardService],
})
export class ProductStockDashboardModule {}
