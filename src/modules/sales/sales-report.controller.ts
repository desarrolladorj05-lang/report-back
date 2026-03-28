import {
  Controller,
  Get,
  Query,
  BadRequestException,
  UseGuards,
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
  constructor(private readonly reportService: SalesReportService) {}

  @UseGuards(JwtAuthGuard)
  @Get("managment-sales")
  async getManagmentReportSales(@Query() query: ManagmentReportDto) {
    // Validamos que venga la fecha
    if (!query.date) {
      throw new BadRequestException("El parámetro 'fecha' es obligatorio");
    }
    console.log(`[GET /managment-sales] Fecha solicitada: ${query.date}`);
    return await this.reportService.getManagmentReportSales(query.date);
  }

@UseGuards(JwtAuthGuard)
  @Get("sales-by-sede")
  async getReporteVentasBySede(@Query() query: SalesBySedeDto): Promise<RespuestaReporteSede[]> {
    console.log(
      ` [GET /sales-by-sede] Local ID: ${query.id_local ?? 'TODOS'} | Fecha: ${query.date}`,
    );
    
    return await this.reportService.getReporteVentasBySede(
      query.id_local,
      query.date,
    );
  }

  @UseGuards(JwtAuthGuard)
@Get("fuel-by-sede")
async getReporteCombustiblesBySede(@Query() query: FuelReportBySedeDto) {
  console.log(
    ` [GET /fuel-by-sede] Local ID: ${query.id_local ?? 'TODAS'} | Fecha: ${query.date}`,
  );

  return await this.reportService.getReporteCombustiblesBySede(
    query.id_local, 
    query.date,
  );
}

  @UseGuards(JwtAuthGuard)
  @Get("clients-full-detail")
  async getAllClientReports(@Query() query: AllClientReportsDto) {
    console.log(
      `📋 [GET /clients-full-detail] Sede: ${query.id_local} | Fecha: ${query.date}`,
    );

    return await this.reportService.getAllClientReports(
      query.id_local,
      query.date,
    );
  }

}
