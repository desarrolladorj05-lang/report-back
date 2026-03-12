import { Injectable } from "@nestjs/common";
import { TenantDataSourceFactory } from "src/config/tenancy/tenant-ds.factory";
import { BaseRepository } from "src/database/repositories/base.repository";
import { 
  SalesReportProcedure, 
  SalesReportResult 
} from "src/database/procedures-documentation/sales-report.procedure";
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
    // El SP retorna un array con un solo objeto JSON en la primera columna
    // resultado: [ { resultado: { ... } } ]
    const firstRow = result[0];
    const reportData = firstRow ? Object.values(firstRow)[0] : null;
    return reportData as SalesReportResult;
  }
}