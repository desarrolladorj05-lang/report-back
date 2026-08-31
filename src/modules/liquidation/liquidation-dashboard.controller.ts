import { Controller, Get, Logger, Query, UseGuards } from "@nestjs/common";
import { JwtAuthGuard } from "src/auth/jwt.auth.guard";
import { LiquidationDashboardDto } from "./liquidation-dashboard.dto";
import { LiquidationDashboardService } from "./liquidation-dashboard.service";

@Controller("report/liquidations")
@UseGuards(JwtAuthGuard)
export class LiquidationDashboardController {
  private readonly logger = new Logger(LiquidationDashboardController.name);

  constructor(private readonly service: LiquidationDashboardService) {}

  @Get("dashboard")
  async getDashboard(@Query() query: LiquidationDashboardDto) {
    const start = Date.now();
    const result = await this.service.getDashboard(
      query.dateFrom,
      query.dateTo,
      query.localNumber,
    );
    this.logger.log(
      `[/report/liquidations/dashboard] Finalizado en ${Date.now() - start}ms`,
    );
    return result;
  }

  @Get("cash-registers")
  async getCashRegisters(@Query() query: LiquidationDashboardDto) {
    const start = Date.now();
    const result = await this.service.getCashRegisters(
      query.dateFrom,
      query.dateTo,
      query.localNumber,
    );
    this.logger.log(
      `[/report/liquidations/cash-registers] Finalizado en ${Date.now() - start}ms (${result.length} cajas)`,
    );
    return result;
  }
}
