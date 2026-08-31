import { Controller, Get, Logger, Query, UseGuards } from "@nestjs/common";
import { JwtAuthGuard } from "src/auth/jwt.auth.guard";
import { ProductStockDashboardDto } from "./product-stock-dashboard.dto";
import { ProductStockDashboardService } from "./product-stock-dashboard.service";

@Controller("report/products")
@UseGuards(JwtAuthGuard)
export class ProductStockDashboardController {
  private readonly logger = new Logger(ProductStockDashboardController.name);

  constructor(private readonly service: ProductStockDashboardService) {}

  @Get("dashboard")
  async getDashboard(@Query() query: ProductStockDashboardDto) {
    const startedAt = Date.now();
    const result = await this.service.getDashboard(
      query.dateFrom,
      query.dateTo,
      query.localNumber,
    );
    this.logger.log(
      `[/report/products/dashboard] Finalizado en ${Date.now() - startedAt}ms`,
    );
    return result;
  }
}
