import { Controller, Get, Query, BadRequestException } from "@nestjs/common";
import { SalesReportService } from "./sales-report.service";
import { ManagmentReportDto } from "./sales-report.dto";


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
}