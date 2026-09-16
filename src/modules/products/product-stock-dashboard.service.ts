import { Injectable, Logger } from "@nestjs/common";
import { validateReportDateRange } from "src/common/helpers/report-date-range.helper";
import { ProductStockDashboardRepository } from "./product-stock-dashboard.repository";

@Injectable()
export class ProductStockDashboardService {
  private readonly logger = new Logger(ProductStockDashboardService.name);

  constructor(private readonly repository: ProductStockDashboardRepository) {}

  async getDashboard(dateFrom: string, dateTo: string, localNumber?: number) {
    const { days } = validateReportDateRange(dateFrom, dateTo);

    this.logger.debug(
      `getDashboard llamado con rango: ${dateFrom} a ${dateTo}, localNumber: ${localNumber ?? "todas"}`,
    );
    const startedAt = Date.now();
    const data = await this.repository.getDashboard(
      dateFrom,
      dateTo,
      localNumber,
    );
    this.logger.debug(
      `Consulta de productos completada en ${Date.now() - startedAt}ms`,
    );
    return {
      period: { dateFrom, dateTo, days },
      totals: data?.totals ?? {},
      daily: data?.daily ?? [],
      products: data?.products ?? [],
      locations: data?.locations ?? [],
      stockByLocation: data?.stockByLocation ?? [],
      recentMovements: data?.recentMovements ?? [],
    };
  }

  async getKardex(
    dateFrom: string,
    dateTo: string,
    productId: number,
    page: number,
    pageSize: number,
  ) {
    validateReportDateRange(dateFrom, dateTo);
    const startedAt = Date.now();
    const result = await this.repository.getKardex(
      dateFrom,
      dateTo,
      productId,
      page,
      pageSize,
    );
    this.logger.debug(
      `Kardex del producto ${productId} completado en ${Date.now() - startedAt}ms: página ${result.page}, ${result.rows.length}/${result.total} filas`,
    );
    return result;
  }

  async getFuelStock(
    dateFrom: string,
    dateTo: string,
    allowedLocalIds?: string[],
  ) {
    const { days } = validateReportDateRange(dateFrom, dateTo);

    const startedAt = Date.now();
    const groups = await this.repository.getFuelStock(
      dateFrom,
      dateTo,
      allowedLocalIds,
    );
    const localPresentation = await this.repository.getLocalPresentation(
      [...new Set(groups.map((group) => group.local_id))],
    );
    const presentationByLocal = new Map(
      localPresentation.map((local) => [local.id_local, local]),
    );
    const number = (value: unknown) => Number(value ?? 0);
    const response = groups.map((group) => {
      const rawRows = Array.isArray(group.rows)
        ? group.rows
        : JSON.parse(group.rows || "[]");
      return {
        localId: group.local_id,
        localName: group.local_name,
        localColor:
          presentationByLocal.get(group.local_id)?.color_hex ?? "#94A3B8",
        localOrder:
          Number(presentationByLocal.get(group.local_id)?.sort_order) || 999,
        warehouseId: group.warehouse_id,
        warehouseName: group.warehouse_name,
        tankName: group.tank_name || "VARIOS",
        productId: number(group.product_id),
        productName: group.product_name,
        rows: rawRows.map((row) => ({
          date: String(row.date),
          stockInitial: number(row.stockInitial),
          income: number(row.income),
          internalConsumption: number(row.internalConsumption),
          warehouseTransfer: number(row.warehouseTransfer),
          sales: number(row.sales),
          externalSales: number(row.externalSales),
          stockTheoretical: number(row.stockTheoretical),
          stockPhysical: number(row.stockPhysical),
          differenceDay: number(row.differenceDay),
        })),
      };
    }).sort(
      (left, right) =>
        left.localOrder - right.localOrder ||
        left.productName.localeCompare(right.productName),
    );
    this.logger.debug(
      `Reporte de stock de combustibles (${dateFrom} a ${dateTo}) completado en ${Date.now() - startedAt}ms: ${response.length} grupos`,
    );
    return { period: { dateFrom, dateTo, days }, groups: response };
  }
}
