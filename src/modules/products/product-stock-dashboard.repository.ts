import { Injectable } from "@nestjs/common";
import { TenantDataSourceFactory } from "src/config/tenancy/tenant-ds.factory";
import {
  ProductStockDashboardProcedure,
  ProductStockDashboardProcedureResult,
} from "src/database/procedures-documentation/product-stock-dashboard";
import { BaseRepository } from "src/database/repositories/base.repository";

@Injectable()
export class ProductStockDashboardRepository extends BaseRepository<any> {
  constructor(dsFactory: TenantDataSourceFactory) {
    super(Object as any, dsFactory);
  }

  async getDashboard(dateFrom: string, dateTo: string, localNumber?: number) {
    const rows = await this.executeProcedure({
      name: ProductStockDashboardProcedure.PRODUCT_STOCK_DASHBOARD.name,
      params: {
        p_date_from: dateFrom,
        p_date_to: dateTo,
        p_local_number: localNumber ?? null,
      },
    });
    const first = rows[0];
    return (first ? Object.values(first)[0] : undefined) as
      | ProductStockDashboardProcedureResult
      | undefined;
  }
}
