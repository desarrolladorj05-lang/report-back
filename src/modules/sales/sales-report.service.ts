import { Injectable, BadRequestException } from "@nestjs/common";
import { SalesReportResult } from "src/database/procedures-documentation/sales-report.procedure";
import { SalesReportRepository } from "./sales-report.repository";
import { DateFormatter } from "src/common/helpers/date-formatter.util";
import { BloqueReporteSede } from "src/database/procedures-documentation/report_sales_by_sede";
import { ReporteCombustiblesResponse } from "src/database/procedures-documentation/report_product_sales_by_sede";

@Injectable()
export class SalesReportService {
  constructor(private reportRepository: SalesReportRepository) {}

  async getManagmentReportSales(fecha: string): Promise<SalesReportResult> {
    if (!DateFormatter.isValidFormat(fecha)) {
      throw new BadRequestException("Formato de fecha inválido");
    }
    const result = await this.reportRepository.getManagmentReportSales(fecha);
    return result;
  }

  async getReporteVentasBySede(idLocal: number, fecha: string): Promise<BloqueReporteSede[]> {
    this.validateParams(idLocal, fecha);
    
    const result = await this.reportRepository.getReporteVentasBySede(idLocal, fecha);
    return result || [];
  }

  async getReporteCombustiblesBySede(idLocal: number, fecha: string): Promise<ReporteCombustiblesResponse> {
    this.validateParams(idLocal, fecha);

    const result = await this.reportRepository.getReporteCombustiblesBySede(idLocal, fecha);

    if (!result) {
      throw new BadRequestException("No se encontró información para la sede y fecha especificada");
    }

    return result;
  }

  /**
   * Helper para centralizar las validaciones de reportes por sede
   */
  private validateParams(idLocal: number, fecha: string) {
    if (!idLocal || isNaN(idLocal)) {
      throw new BadRequestException("El ID del local es obligatorio y debe ser un número");
    }

    if (!DateFormatter.isValidFormat(fecha)) {
      throw new BadRequestException("Formato de fecha inválido. Use DD/MM/YYYY");
    }
  }
}