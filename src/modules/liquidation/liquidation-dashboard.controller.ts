import { Controller, Get, Logger, Query, Req, UseGuards } from "@nestjs/common";
import { JwtAuthGuard } from "src/auth/jwt.auth.guard";
import { AuthzService } from "src/auth/authz.service";
import { AuthenticatedRequest } from "src/auth/authz.types";
import { MenuAccessGuard } from "src/auth/menu-access.guard";
import { RequireMenu } from "src/auth/require-menu.decorator";
import { LiquidationDashboardDto } from "./liquidation-dashboard.dto";
import { LiquidationDashboardService } from "./liquidation-dashboard.service";

@Controller("report/liquidations")
@UseGuards(JwtAuthGuard, MenuAccessGuard)
@RequireMenu("/liquidaciones")
export class LiquidationDashboardController {
  private readonly logger = new Logger(LiquidationDashboardController.name);

  constructor(
    private readonly service: LiquidationDashboardService,
    private readonly authzService: AuthzService,
  ) {}

  @Get("dashboard")
  async getDashboard(
    @Query() query: LiquidationDashboardDto,
    @Req() request: AuthenticatedRequest,
  ) {
    const context = await this.authzService.getContext(request.user.userId);
    if (query.localNumber !== undefined) {
      await this.authzService.resolveLocalNumber(
        request.user.userId,
        query.localNumber,
      );
    }
    const start = Date.now();
    const result = await this.service.getDashboardForScope(
      query.dateFrom,
      query.dateTo,
      query.localNumber,
      context,
    );
    this.logger.log(
      `[/report/liquidations/dashboard] Finalizado en ${Date.now() - start}ms`,
    );
    return result;
  }

  @Get("cash-registers")
  async getCashRegisters(
    @Query() query: LiquidationDashboardDto,
    @Req() request: AuthenticatedRequest,
  ) {
    const context = await this.authzService.getContext(request.user.userId);
    if (query.localNumber !== undefined) {
      await this.authzService.resolveLocalNumber(
        request.user.userId,
        query.localNumber,
      );
    }
    const start = Date.now();
    const result = await this.service.getCashRegistersForScope(
      query.dateFrom,
      query.dateTo,
      query.localNumber,
      context,
    );
    this.logger.log(
      `[/report/liquidations/cash-registers] Finalizado en ${Date.now() - start}ms (${result.length} cajas)`,
    );
    return result;
  }
}
