import { Controller, Get, Query, BadRequestException } from "@nestjs/common";
import { SalesReportService } from "./sales-report.service";
import { FuelReportBySedeDto, ManagmentReportDto, SalesBySedeDto } from "./sales-report.dto";


@Controller("report")
export class SalesReportController {
  constructor(private readonly reportService: SalesReportService) {}

  @Get("managment-sales")
  async getManagmentReportSales(@Query() query: ManagmentReportDto) {
    // Validamos que venga la fecha
    if (!query.date) {
      throw new BadRequestException("El parámetro 'fecha' es obligatorio");
    }
    console.log(`📊 [GET /managment-sales] Fecha solicitada: ${query.date}`);
    return await this.reportService.getManagmentReportSales(query.date);
  }

  @Get("sales-by-sede")
  async getReporteVentasBySede(@Query() query: SalesBySedeDto) {    
    console.log(`📊 [GET /sales-by-sede] Local ID: ${query.id_local} | Fecha: ${query.date}`);
    return await this.reportService.getReporteVentasBySede(
      query.id_local, 
      query.date
    );
  }

  @Get("fuel-by-sede")
  async getReporteCombustiblesBySede(@Query() query: FuelReportBySedeDto) {
    console.log(`⛽ [GET /fuel-by-sede] Local ID: ${query.id_local} | Fecha: ${query.date}`);
    
    return await this.reportService.getReporteCombustiblesBySede(
      query.id_local, 
      query.date
    );
  }
}