import { Injectable } from "@nestjs/common";
import { TenantDataSourceFactory } from "src/config/tenancy/tenant-ds.factory";
import { BaseRepository } from "src/database/repositories/base.repository";
import {
  SalesReportProcedure,
  SalesReportResult,
} from "src/database/procedures-documentation/sales-report.procedure";
import {
  BloqueReporteSede,
  SalesBySedeProcedure,
} from "src/database/procedures-documentation/report_sales_by_sede";
import {
  ReporteCombustiblesResponse,
  SaleFuelReportProcedure,
} from "src/database/procedures-documentation/report_product_sales_by_sede";
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
    idLocal: number,
    fecha: string,
  ): Promise<BloqueReporteSede[]> {
    const result = await this.executeProcedure({
      name: SalesBySedeProcedure.REPORTE_VENTAS_BY_SEDE.name,
      params: {
        p_id_local: idLocal,
        p_fecha_busqueda: fecha,
      },
    });
    const firstRow = result[0];
    const reportData = firstRow ? Object.values(firstRow)[0] : [];

    return reportData as BloqueReporteSede[];
  }

  async getReporteCombustiblesBySede(
    idLocal: number,
    fecha: string,
  ): Promise<ReporteCombustiblesResponse> {
    const result = await this.executeProcedure({
      name: SaleFuelReportProcedure.REPORTE_COMBUSTIBLES_BY_SEDE.name,
      params: {
        p_id_local: idLocal,
        p_fecha_busqueda: fecha,
      },
    });

    const firstRow = result[0];
    // Extraemos el JSONB de la primera columna
    const reportData = firstRow ? Object.values(firstRow)[0] : null;

    return reportData as ReporteCombustiblesResponse;
  }
}
