import { Injectable } from "@nestjs/common";
import { TenantDataSourceFactory } from "../../config/tenancy/tenant-ds.factory";
import {
  ReportProcedure,
  SalesReportResult,
} from "../../database/procedures-documentation/report.procedures";
import { BaseRepository } from "../../database/repositories/base.repository";

@Injectable()
export class ReportRepository extends BaseRepository<any> {
  getRepository() {
    throw new Error("Method not implement.");
  }

  constructor(dsFactory: TenantDataSourceFactory) {
    super(Object as any, dsFactory);
  }

  async getDashboardVentas(params: {
    local: number;
    desde: string;
    hasta: string;
  }): Promise<SalesReportResult> {
    const result = await this.executeProcedure({
      name: ReportProcedure.REPORT_DASHBOARD_VENTAS.name,
      params: {
        p_local: params.local,
        p_desde: params.desde,
        p_hasta: params.hasta,
      },
    });

    // El SP devuelve un JSONB en la primera columna
    const firstRow = result[0];
    const reportData = (
      firstRow ? Object.values(firstRow)[0] : null
    ) as SalesReportResult;

    // Retornar con valores por defecto si es null
    return {
      summary: reportData?.summary || {
        totalVentas: 0,
        montoTotal: 0,
      },
      details: reportData?.details || [],
    };
  }
}
