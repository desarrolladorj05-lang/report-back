import { BadRequestException, Injectable, Logger } from "@nestjs/common";
import { ProductStockDashboardRepository } from "./product-stock-dashboard.repository";

@Injectable()
export class ProductStockDashboardService {
  private readonly logger = new Logger(ProductStockDashboardService.name);

  constructor(private readonly repository: ProductStockDashboardRepository) {}

  async getDashboard(dateFrom: string, dateTo: string, localNumber?: number) {
    const from = new Date(`${dateFrom}T00:00:00Z`);
    const to = new Date(`${dateTo}T00:00:00Z`);
    if (from > to) throw new BadRequestException("Rango de fechas inválido");
    const days = Math.floor((to.getTime() - from.getTime()) / 86400000) + 1;
    if (days > 366)
      throw new BadRequestException("El rango máximo es de 366 días");

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
    const from = new Date(`${dateFrom}T00:00:00Z`);
    const to = new Date(`${dateTo}T00:00:00Z`);
    if (from > to) throw new BadRequestException("Rango de fechas inválido");
    const days = Math.floor((to.getTime() - from.getTime()) / 86400000) + 1;
    if (days > 366) {
      throw new BadRequestException("El rango máximo es de 366 días");
    }

    const startedAt = Date.now();
    const groups = await this.repository.getFuelStock(
      dateFrom,
      dateTo,
      allowedLocalIds,
    );
    const number = (value: unknown) => Number(value ?? 0);
    const response = groups.map((group) => {
      const rawRows = Array.isArray(group.rows)
        ? group.rows
        : JSON.parse(group.rows || "[]");
      return {
        localId: group.local_id,
        localName: group.local_name,
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
    });
    this.logger.debug(
      `Reporte de stock de combustibles (${dateFrom} a ${dateTo}) completado en ${Date.now() - startedAt}ms: ${response.length} grupos`,
    );
    return { period: { dateFrom, dateTo, days }, groups: response };
  }
}
