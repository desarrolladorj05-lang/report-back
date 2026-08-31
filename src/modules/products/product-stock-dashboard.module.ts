import { Module } from "@nestjs/common";
import { ProductStockDashboardController } from "./product-stock-dashboard.controller";
import { ProductStockDashboardRepository } from "./product-stock-dashboard.repository";
import { ProductStockDashboardService } from "./product-stock-dashboard.service";

@Module({
  controllers: [ProductStockDashboardController],
  providers: [ProductStockDashboardRepository, ProductStockDashboardService],
})
export class ProductStockDashboardModule {}
