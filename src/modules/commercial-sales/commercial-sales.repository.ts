import { Injectable } from "@nestjs/common";
import { TenantDataSourceFactory } from "src/config/tenancy/tenant-ds.factory";
import {
  CommercialSalesReportProcedure,
  CommercialSalesReportRow,
} from "src/database/procedures-documentation/commercial-sales-report";
import { BaseRepository } from "src/database/repositories/base.repository";

@Injectable()
export class CommercialSalesRepository extends BaseRepository<any> {
  constructor(dsFactory: TenantDataSourceFactory) {
    super(Object as any, dsFactory);
  }

  getReport(dateFrom: string, dateTo: string, localIds?: string[]) {
    return this.executeProcedure({
      name: CommercialSalesReportProcedure.COMMERCIAL_SALES_REPORT.name,
      params: {
        p_date_from: dateFrom,
        p_date_to: dateTo,
        p_local_ids: localIds?.length ? localIds : null,
      },
    }) as Promise<CommercialSalesReportRow[]>;
  }
}
