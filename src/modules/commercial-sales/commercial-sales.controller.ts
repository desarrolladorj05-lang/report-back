import { Controller, Get, Logger, Query, Req, UseGuards } from "@nestjs/common";
import { JwtAuthGuard } from "src/auth/jwt.auth.guard";
import { AuthzService } from "src/auth/authz.service";
import { AuthenticatedRequest } from "src/auth/authz.types";
import { MenuAccessGuard } from "src/auth/menu-access.guard";
import { RequireMenu } from "src/auth/require-menu.decorator";
import { CommercialSalesReportDto } from "./commercial-sales.dto";
import { CommercialSalesService } from "./commercial-sales.service";

@Controller("report/commercial-sales")
@UseGuards(JwtAuthGuard, MenuAccessGuard)
@RequireMenu("/ventas-comercial")
export class CommercialSalesController {
  private readonly logger = new Logger(CommercialSalesController.name);

  constructor(
    private readonly service: CommercialSalesService,
    private readonly authzService: AuthzService,
  ) {}

  @Get()
  async getReport(
    @Query() query: CommercialSalesReportDto,
    @Req() request: AuthenticatedRequest,
  ) {
    const context = await this.authzService.getContext(request.user.userId);
    const startedAt = Date.now();
    const result = await this.service.getReport(
      query.dateFrom,
      query.dateTo,
      context.hasAllLocals
        ? undefined
        : context.locals.map((local) => local.id),
    );
    this.logger.log(
      `[/report/commercial-sales] Finalizado en ${Date.now() - startedAt}ms`,
    );
    return result;
  }
}
