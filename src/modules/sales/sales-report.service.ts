import { Injectable, BadRequestException, Logger } from "@nestjs/common";
import { SalesReportResult } from "src/database/procedures-documentation/sales-report.procedure";
import { SalesReportRepository } from "./sales-report.repository";
import { DateFormatter } from "src/common/helpers/date-formatter.util";
import { RespuestaReporteSede } from "src/database/procedures-documentation/report_sales_by_sede";
import { ReporteDetalleClientesResponse } from "src/database/procedures-documentation/detail_client_report";
import { ReporteCombustiblesSede } from "src/database/procedures-documentation/report_product_sales_by_sede";

@Injectable()
export class SalesReportService {
  private readonly logger = new Logger(SalesReportService.name);

  constructor(private reportRepository: SalesReportRepository) {}

  async getManagmentReportSales(fecha: string): Promise<SalesReportResult> {
    this.logger.debug(`getManagmentReportSales llamado con fecha: ${fecha}`);

    if (!DateFormatter.isValidFormat(fecha)) {
      this.logger.warn(`Formato de fecha inválido recibido: ${fecha}`);
      throw new BadRequestException("Formato de fecha inválido");
    }

    const result = await this.reportRepository.getManagmentReportSales(fecha);
    this.logger.debug(
      `getManagmentReportSales completado exitosamente para fecha: ${fecha}`,
    );
    return result;
  }

  async getReporteVentasBySede(
    idLocal?: number,
    fecha?: string,
  ): Promise<RespuestaReporteSede[]> {
    this.logger.debug(
      `getReporteVentasBySede llamado con idLocal: ${idLocal}, fecha: ${fecha}`,
    );

    // Validamos solo la fecha, ya que el idLocal puede ser undefined
    if (!fecha) {
      this.logger.warn("getReporteVentasBySede llamado sin fecha obligatoria");
      throw new Error("La fecha es obligatoria");
    }

    const result = await this.reportRepository.getReporteVentasBySede(
      idLocal,
      fecha,
    );

    this.logger.debug(
      `getReporteVentasBySede completado: ${result.length || 0} registros encontrados`,
    );
    return result; // Ya viene como array desde el repository
  }
  async getReporteCombustiblesBySede(
    idLocal?: number,
    fecha?: string,
  ): Promise<ReporteCombustiblesSede[]> {
    this.logger.debug(
      `getReporteCombustiblesBySede llamado con idLocal: ${idLocal}, fecha: ${fecha}`,
    );

    if (!fecha) {
      this.logger.warn(
        "getReporteCombustiblesBySede llamado sin fecha obligatoria",
      );
      throw new Error("La fecha es obligatoria");
    }

    const result = await this.reportRepository.getFuelReportBySede(
      idLocal,
      fecha,
    );

    this.logger.debug(
      `getReporteCombustiblesBySede: recibidos ${result?.length || 0} registros del repositorio`,
    );

    if (!result || result.length === 0) {
      this.logger.warn(
        `No se encontró información de combustibles para idLocal: ${idLocal}, fecha: ${fecha}`,
      );
      throw new BadRequestException(
        "No se encontró información de combustibles para los parámetros especificados",
      );
    }

    return result;
  }

  async getAllClientReports(
    idLocal: number,
    fecha: string,
  ): Promise<ReporteDetalleClientesResponse> {
    this.logger.debug(
      `getAllClientReports llamado con idLocal: ${idLocal}, fecha: ${fecha}`,
    );

    // 1. Validamos los parámetros usando tu helper existente
    this.validateParams(idLocal, fecha);

    // 2. Llamamos al repositorio
    const result = await this.reportRepository.getAllClientReports(
      idLocal,
      fecha,
    );

    // 3. Verificamos que tengamos datos (si el SP devuelve null por algún motivo)
    if (!result) {
      this.logger.warn(
        `getAllClientReports: repositorio devolvió null para idLocal: ${idLocal}, fecha: ${fecha}`,
      );
      // Retornamos un objeto con arrays vacíos para que el front no rompa
      return {
        descuentos: [],
        transferencias: [],
        creditos: [],
        adelantos: [],
        consumo_interno: [],
        canjes: [],
      };
    }

    this.logger.debug(
      `getAllClientReports completado exitosamente para idLocal: ${idLocal}, fecha: ${fecha}`,
    );
    return result;
  }

  /**
   * Helper para centralizar las validaciones de reportes por sede
   */
  private validateParams(idLocal: number, fecha: string) {
    if (!idLocal || isNaN(idLocal)) {
      throw new BadRequestException(
        "El ID del local es obligatorio y debe ser un número",
      );
    }

    if (!DateFormatter.isValidFormat(fecha)) {
      throw new BadRequestException(
        "Formato de fecha inválido. Use DD/MM/YYYY",
      );
    }
  }
}
