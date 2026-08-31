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

  async getKardex(
    dateFrom: string,
    dateTo: string,
    productId: number,
    page: number,
    pageSize: number,
  ) {
    const rows = await this.executeProcedure({
      name: ProductStockDashboardProcedure.PRODUCT_KARDEX.name,
      params: {
        p_date_from: dateFrom,
        p_date_to: dateTo,
        p_product_id: productId,
        p_page: page,
        p_page_size: pageSize,
      },
    });
    const first = rows[0];
    const result = first
      ? (Object.values(first)[0] as {
          page?: number;
          pageSize?: number;
          total?: number;
          rows?: unknown[];
        })
      : undefined;
    return {
      page: result?.page ?? page,
      pageSize: result?.pageSize ?? pageSize,
      total: result?.total ?? 0,
      rows: result?.rows ?? [],
    };
  }
}
