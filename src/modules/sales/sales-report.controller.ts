import {
  Controller,
  Get,
  Query,
  BadRequestException,
  UseGuards,
  Logger,
  Req,
} from "@nestjs/common";
import { SalesReportService } from "./sales-report.service";
import {
  AllClientReportsDto,
  ContometroByProductDto,
  FuelReportBySedeDto,
  ManagmentReportDto,
  SalesBySedeDto,
} from "./sales-report.dto";
import { JwtAuthGuard } from "../../auth/jwt.auth.guard";
import { RespuestaReporteSede } from "src/database/procedures-documentation/report_sales_by_sede";
import { MenuAccessGuard } from "src/auth/menu-access.guard";
import { RequireMenu } from "src/auth/require-menu.decorator";
import { AuthzService } from "src/auth/authz.service";
import { AuthenticatedRequest } from "src/auth/authz.types";

@Controller("report")
@UseGuards(JwtAuthGuard, MenuAccessGuard)
@RequireMenu("/ventas")
export class SalesReportController {
  private readonly logger = new Logger(SalesReportController.name);

  constructor(
    private readonly reportService: SalesReportService,
    private readonly authzService: AuthzService,
  ) {}

  @Get("managment-sales")
  async getManagmentReportSales(
    @Query() query: ManagmentReportDto,
    @Req() request: AuthenticatedRequest,
  ) {
    if (!query.date) throw new BadRequestException("Fecha obligatoria");

    const start = Date.now();
    const [result, context] = await Promise.all([
      this.reportService.getManagmentReportSales(query.date),
      this.authzService.getContext(request.user.userId),
    ]);
    const scopedResult = context.hasAllLocals
      ? result
      : this.filterSalesReport(result, context.locals.map((local) => local.number));

    this.logger.log(`[/managment-sales] Finalizado en ${Date.now() - start}ms`);
    return scopedResult;
  }

  @Get("sales-by-sede")
  async getReporteVentasBySede(
    @Query() query: SalesBySedeDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<RespuestaReporteSede[]> {
    const scope = await this.authzService.resolveLocalNumber(
      request.user.userId,
      query.id_local,
    );
    const start = Date.now();
    const result = await this.reportService.getReporteVentasBySede(
      scope.localNumber,
      query.date,
    );

    this.logger.log(`[/sales-by-sede] Finalizado en ${Date.now() - start}ms`);
    return result;
  }

  @Get("fuel-by-sede")
  async getReporteCombustiblesBySede(
    @Query() query: FuelReportBySedeDto,
    @Req() request: AuthenticatedRequest,
  ) {
    const scope = await this.authzService.resolveLocalNumber(
      request.user.userId,
      query.id_local,
    );
    const start = Date.now();
    const result = await this.reportService.getReporteCombustiblesBySede(
      scope.localNumber,
      query.date,
    );

    this.logger.log(`[/fuel-by-sede] Finalizado en ${Date.now() - start}ms`);
    return result;
  }

  @Get("contometer-by-product")
  async getContometroByProduct(
    @Query() query: ContometroByProductDto,
    @Req() request: AuthenticatedRequest,
  ) {
    await this.authzService.resolveLocalNumber(request.user.userId, query.id_local);
    const start = Date.now();
    const result = await this.reportService.getContometroByProduct(
      query.id_local!,
      query.date,
      query.id_turno,
      query.id_producto,
    );

    this.logger.log(
      `[/contometro-by-product] Finalizado en ${Date.now() - start}ms`,
    );
    return result;
  }

  @Get("clients-full-detail")
  async getAllClientReports(
    @Query() query: AllClientReportsDto,
    @Req() request: AuthenticatedRequest,
  ) {
    await this.authzService.resolveLocalNumber(request.user.userId, query.id_local);
    const start = Date.now();
    const result = await this.reportService.getAllClientReports(
      query.id_local,
      query.date,
      query.id_concepto,
      query.id_turno,
    );

    this.logger.log(
      `[/clients-full-detail] Finalizado en ${Date.now() - start}ms`,
    );
    return result;
  }

  @Get("time")
  getServerTime() {
    return {
      serverDate: new Date().toISOString(),
      localTime: new Date().toLocaleString("es-PE", {
        timeZone: "America/Lima",
      }),
    };
  }

  private filterSalesReport(result: any, localNumbers: number[]) {
    const allowed = new Set(localNumbers.map(Number));
    const sedes = (result.sedes ?? []).filter((item: any) =>
      allowed.has(Number(item.idlocal)),
    );
    const analytics = (result.analytics ?? []).filter((item: any) =>
      allowed.has(Number(item.idlocal)),
    );
    const ventaHoy = sedes.reduce(
      (sum: number, item: any) => sum + Number(item.monto_hoy ?? 0),
      0,
    );
    const ventaAyer = sedes.reduce(
      (sum: number, item: any) => sum + Number(item.monto_ayer ?? 0),
      0,
    );
    const history = new Map<string, number>();
    analytics.forEach((item: any) =>
      (item.serie_historica ?? []).forEach((point: any) =>
        history.set(
          String(point.fecha),
          (history.get(String(point.fecha)) ?? 0) + Number(point.venta ?? 0),
        ),
      ),
    );
    return {
      ...result,
      sedes,
      analytics,
      venta_total_todas_sedes: ventaHoy,
      variacion_total_global: ventaAyer
        ? ((ventaHoy - ventaAyer) / Math.abs(ventaAyer)) * 100
        : ventaHoy
          ? 100
          : 0,
      total_acumulado_global: analytics.reduce(
        (sum: number, item: any) => sum + Number(item.total_acumulado_mes ?? 0),
        0,
      ),
      analytics_general: Array.from(history, ([fecha, venta]) => ({ fecha, venta }))
        .sort((a, b) => a.fecha.localeCompare(b.fecha)),
    };
  }
}
