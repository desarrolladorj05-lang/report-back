import { Injectable, BadRequestException } from "@nestjs/common";
import { SalesReportResult } from "src/database/procedures-documentation/sales-report.procedure";
import { SalesReportRepository } from "./sales-report.repository";
import { DateFormatter } from "src/common/helpers/date-formatter.util";
import { BloqueReporteSede } from "src/database/procedures-documentation/report_sales_by_sede";
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

  async getReporteVentasBySede(idLocal: number, fecha: string): Promise<BloqueReporteSede[]> {
    if (!idLocal || isNaN(idLocal)) {
      throw new BadRequestException("El ID del local es obligatorio y debe ser un número");
    }

    if (!DateFormatter.isValidFormat(fecha)) {
      throw new BadRequestException("Formato de fecha inválido. Use DD/MM/YYYY");
    }
    const result = await this.reportRepository.getReporteVentasBySede(idLocal, fecha);

    if (!result || result.length === 0) {
      return [];
    }
    
    return result;
  }

}