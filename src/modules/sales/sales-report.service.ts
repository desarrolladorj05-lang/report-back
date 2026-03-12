import { Injectable, BadRequestException } from "@nestjs/common";
import { SalesReportResult } from "src/database/procedures-documentation/sales-report.procedure";
import { SalesReportRepository } from "./sales-report.repository";
import { DateFormatter } from "src/common/helpers/date-formatter.util";
@Injectable()
export class SalesReportService {
  constructor(private reportRepository: SalesReportRepository) {}

  async getManagmentReportSales(fecha: string): Promise<SalesReportResult> {
    if (!DateFormatter.isValidFormat(fecha)) {
      throw new BadRequestException("Formato de fecha inválido");
    }
    const fechaDB = DateFormatter.toDatabaseFormat(fecha);
    // Llamar al repositorio
    const result = await this.reportRepository.getManagmentReportSales(fecha);
    
    return result;
  }
}