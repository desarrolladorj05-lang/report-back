import {
  Controller,
  Get,
  Query,
  BadRequestException,
  UseGuards,
  Logger,
} from "@nestjs/common";
import { SalesReportService } from "./sales-report.service";
import {
  AllClientReportsDto,
  FuelReportBySedeDto,
  ManagmentReportDto,
  SalesBySedeDto,
} from "./sales-report.dto";
import { JwtAuthGuard } from "../../auth/jwt.auth.guard";
import { RespuestaReporteSede } from "src/database/procedures-documentation/report_sales_by_sede";

@Controller("report")
export class SalesReportController {
  private readonly logger = new Logger(SalesReportController.name);

  constructor(private readonly reportService: SalesReportService) {}

  @UseGuards(JwtAuthGuard)
  @Get("managment-sales")
  async getManagmentReportSales(@Query() query: ManagmentReportDto) {
    if (!query.date) throw new BadRequestException("Fecha obligatoria");

    const start = Date.now();
    const result = await this.reportService.getManagmentReportSales(query.date);

    this.logger.log(`[/managment-sales] Finalizado en ${Date.now() - start}ms`);
    return result;
  }

  @UseGuards(JwtAuthGuard)
  @Get("sales-by-sede")
  async getReporteVentasBySede(
    @Query() query: SalesBySedeDto,
  ): Promise<RespuestaReporteSede[]> {
    const start = Date.now();
    const result = await this.reportService.getReporteVentasBySede(
      query.id_local,
      query.date,
    );

    this.logger.log(`[/sales-by-sede] Finalizado en ${Date.now() - start}ms`);
    return result;
  }

  @UseGuards(JwtAuthGuard)
  @Get("fuel-by-sede")
  async getReporteCombustiblesBySede(@Query() query: FuelReportBySedeDto) {
    const start = Date.now();
    const result = await this.reportService.getReporteCombustiblesBySede(
      query.id_local,
      query.date,
    );

    this.logger.log(`[/fuel-by-sede] Finalizado en ${Date.now() - start}ms`);
    return result;
  }

  @UseGuards(JwtAuthGuard)
  @Get("clients-full-detail")
  async getAllClientReports(@Query() query: AllClientReportsDto) {
    const start = Date.now();
    const result = await this.reportService.getAllClientReports(
      query.id_local,
      query.date,
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
}
