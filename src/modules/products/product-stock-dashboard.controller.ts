import {
  Controller,
  ForbiddenException,
  Get,
  Logger,
  Query,
  Req,
  UseGuards,
} from "@nestjs/common";
import { JwtAuthGuard } from "src/auth/jwt.auth.guard";
import { AuthzService } from "src/auth/authz.service";
import { AuthenticatedRequest } from "src/auth/authz.types";
import { MenuAccessGuard } from "src/auth/menu-access.guard";
import { RequireMenu } from "src/auth/require-menu.decorator";
import { ProductStockDashboardDto } from "./product-stock-dashboard.dto";
import { ProductStockDashboardService } from "./product-stock-dashboard.service";

@Controller("report/products")
@UseGuards(JwtAuthGuard, MenuAccessGuard)
@RequireMenu("/productos")
export class ProductStockDashboardController {
  private readonly logger = new Logger(ProductStockDashboardController.name);

  constructor(
    private readonly service: ProductStockDashboardService,
    private readonly authzService: AuthzService,
  ) {}

  @Get("dashboard")
  async getDashboard(
    @Query() query: ProductStockDashboardDto,
    @Req() request: AuthenticatedRequest,
  ) {
    const scope = await this.authzService.resolveLocalNumber(
      request.user.userId,
      query.localNumber,
    );
    const startedAt = Date.now();
    const result = await this.service.getDashboard(
      query.dateFrom,
      query.dateTo,
      scope.localNumber,
    );
    this.logger.log(
      `[/report/products/dashboard] Finalizado en ${Date.now() - startedAt}ms`,
    );
    return result;
  }

  @Get("kardex")
  async getKardex(
    @Query() query: ProductStockDashboardDto,
    @Req() request: AuthenticatedRequest,
  ) {
    const context = await this.authzService.getContext(request.user.userId);
    if (!context.hasAllLocals) {
      throw new ForbiddenException(
        "El kardex requiere soporte de filtrado por sede antes de habilitarse para este usuario",
      );
    }
    if (!query.productId) return [];
    return this.service.getKardex(
      query.dateFrom,
      query.dateTo,
      query.productId,
      query.page ?? 1,
      query.pageSize ?? 100,
    );
  }

  @Get("fuel-stock")
  async getFuelStock(
    @Query() query: ProductStockDashboardDto,
    @Req() request: AuthenticatedRequest,
  ) {
    const context = await this.authzService.getContext(request.user.userId);
    const startedAt = Date.now();
    const result = await this.service.getFuelStock(
      query.dateFrom,
      query.dateTo,
      context.hasAllLocals
        ? undefined
        : context.locals.map((local) => local.id),
    );
    this.logger.log(
      `[/report/products/fuel-stock] Finalizado en ${Date.now() - startedAt}ms`,
    );
    return result;
  }
}
