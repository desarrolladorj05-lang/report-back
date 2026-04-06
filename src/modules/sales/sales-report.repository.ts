import { Injectable } from "@nestjs/common";
import { TenantDataSourceFactory } from "src/config/tenancy/tenant-ds.factory";
import { BaseRepository } from "src/database/repositories/base.repository";
import {
  SalesReportProcedure,
  SalesReportResult,
} from "src/database/procedures-documentation/sales-report.procedure";
import {
  BloqueReporteSede,
  RespuestaReporteSede,
  SalesBySedeProcedure,
} from "src/database/procedures-documentation/report_sales_by_sede";
import {
  ReporteCombustiblesSede,
  SaleFuelReportProcedure,
} from "src/database/procedures-documentation/report_product_sales_by_sede";
import {
  ClientReportsProcedure,
  ReporteDetalleClientesResponse,
} from "src/database/procedures-documentation/detail_client_report";
@Injectable()
export class SalesReportRepository extends BaseRepository<any> {
  getRepository() {
    throw new Error("Method not implement.");
  }
  constructor(dsFactory: TenantDataSourceFactory) {
    super(Object as any, dsFactory);
  }
  async getManagmentReportSales(fecha: string): Promise<SalesReportResult> {
    const result = await this.executeProcedure({
      name: SalesReportProcedure.MANAGMENT_REPORT_SALES.name,
      params: {
        p_fecha_busqueda: fecha,
      },
    });

    const firstRow = result[0];
    const reportData = firstRow ? Object.values(firstRow)[0] : null;
    return reportData as SalesReportResult;
  }

  async getReporteVentasBySede(
    idLocal?: number,
    fecha?: string,
  ): Promise<RespuestaReporteSede[]> {
    const result = await this.executeProcedure({
      name: SalesBySedeProcedure.REPORTE_VENTAS_BY_SEDE.name,
      params: {
        p_id_local: idLocal ?? null,
        p_fecha_busqueda: fecha,
      },
    });
    const rawData = result[0] ? Object.values(result[0])[0] : null;
    if (!rawData) return [];
    return Array.isArray(rawData) ? rawData : [rawData as RespuestaReporteSede];
  }

  async getFuelReportBySede(
    idLocal?: number,
    fecha?: string,
  ): Promise<ReporteCombustiblesSede[]> {
    const result = await this.executeProcedure({
      name: SaleFuelReportProcedure.REPORTE_COMBUSTIBLES_BY_SEDE.name,
      params: {
        p_id_local: idLocal ?? null,
        p_fecha_busqueda: fecha,
      },
    });

    const rawData = result[0] ? Object.values(result[0])[0] : null;

    if (!rawData) return [];

    // NORMALIZACIÓN: Siempre devolvemos un Array
    return Array.isArray(rawData)
      ? rawData
      : [rawData as ReporteCombustiblesSede];
  }

  async getAllClientReports(
    idLocal: number,
    fecha: string,
  ): Promise<ReporteDetalleClientesResponse> {
    const result = await this.executeProcedure({
      name: ClientReportsProcedure.GET_ALL_CLIENT_REPORTS.name,
      params: {
        p_id_local: idLocal,
        p_fecha_busqueda: fecha,
      },
    });

    // Como el SP devuelve RETURNS TABLE (resultado jsonb)
    const firstRow = result[0];

    // Extraemos la columna 'resultado'
    const reportData = firstRow ? firstRow["resultado"] : null;

    return reportData as ReporteDetalleClientesResponse;
  }
}
