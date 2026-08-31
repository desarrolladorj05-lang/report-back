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
}
