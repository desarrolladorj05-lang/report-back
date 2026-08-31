import { BadRequestException, Injectable, Logger } from "@nestjs/common";
import { LiquidationDashboardRepository } from "./liquidation-dashboard.repository";
import {
  LiquidationCashRegister,
  LiquidationDashboardResponse,
} from "./liquidation-dashboard.types";

@Injectable()
export class LiquidationDashboardService {
  private readonly logger = new Logger(LiquidationDashboardService.name);

  constructor(private readonly repository: LiquidationDashboardRepository) {}

  async getDashboard(
    dateFrom: string,
    dateTo: string,
    localNumber?: number,
  ): Promise<LiquidationDashboardResponse> {
    this.logger.debug(
      `getDashboard llamado con rango: ${dateFrom} a ${dateTo}, localNumber: ${localNumber ?? "todas"}`,
    );
    const from = new Date(`${dateFrom}T00:00:00Z`);
    const to = new Date(`${dateTo}T00:00:00Z`);
    if (from > to)
      throw new BadRequestException("dateFrom no puede ser posterior a dateTo");
    const days = Math.floor((to.getTime() - from.getTime()) / 86400000) + 1;
    if (days > 366)
      throw new BadRequestException("El rango máximo es de 366 días");

    const previousTo = new Date(from);
    previousTo.setUTCDate(previousTo.getUTCDate() - 1);
    const previousFrom = new Date(previousTo);
    previousFrom.setUTCDate(previousFrom.getUTCDate() - days + 1);
    const previousDateFrom = previousFrom.toISOString().slice(0, 10);
    const previousDateTo = previousTo.toISOString().slice(0, 10);

    const currentStart = Date.now();
    const previousStart = Date.now();
    const [data, previousData] = await Promise.all([
      this.repository
        .getDashboard(dateFrom, dateTo, localNumber)
        .then((result) => {
          this.logger.debug(
            `Consulta periodo actual (${dateFrom} a ${dateTo}) completada en ${Date.now() - currentStart}ms`,
          );
          return result;
        }),
      this.repository
        .getDashboard(previousDateFrom, previousDateTo, localNumber)
        .then((result) => {
          this.logger.debug(
            `Consulta periodo anterior (${previousDateFrom} a ${previousDateTo}) completada en ${Date.now() - previousStart}ms`,
          );
          return result;
        }),
    ]);
    const number = (value: unknown) => Number(value ?? 0);
    const summarize = (locations: typeof data.locations) =>
      locations.reduce(
        (acc, row) => ({
          totalToRender: acc.totalToRender + number(row.total_to_render),
          totalCollected: acc.totalCollected + number(row.total_collected),
          difference: acc.difference + number(row.difference),
          liquidationCount:
            acc.liquidationCount + number(row.liquidation_count),
          compliantCount: acc.compliantCount + number(row.compliant_count),
          pendingCount: acc.pendingCount + number(row.pending_count),
        }),
        {
          totalToRender: 0,
          totalCollected: 0,
          difference: 0,
          liquidationCount: 0,
          compliantCount: 0,
          pendingCount: 0,
        },
      );
    const totals = summarize(data.locations);
    const previousTotals = summarize(previousData.locations);
    const percentageChange = (current: number, previous: number) => {
      if (previous === 0) return current === 0 ? 0 : 100;
      return ((current - previous) / Math.abs(previous)) * 100;
    };
    const deposited = data.methods.reduce(
      (sum, row) => sum + number(row.deposited),
      0,
    );
    const collected = data.methods.reduce(
      (sum, row) => sum + number(row.collected),
      0,
    );
    const response: LiquidationDashboardResponse = {
      period: { dateFrom, dateTo, days },
      comparison: {
        period: { dateFrom: previousDateFrom, dateTo: previousDateTo },
        totalToRender: previousTotals.totalToRender,
        totalCollected: previousTotals.totalCollected,
        difference: previousTotals.difference,
        liquidationCount: previousTotals.liquidationCount,
        pendingCount: previousTotals.pendingCount,
        totalToRenderChange: percentageChange(
          totals.totalToRender,
          previousTotals.totalToRender,
        ),
        totalCollectedChange: percentageChange(
          totals.totalCollected,
          previousTotals.totalCollected,
        ),
        differenceChange: percentageChange(
          totals.difference,
          previousTotals.difference,
        ),
        liquidationCountChange: percentageChange(
          totals.liquidationCount,
          previousTotals.liquidationCount,
        ),
        pendingCountChange: percentageChange(
          totals.pendingCount,
          previousTotals.pendingCount,
        ),
      },
      totals: {
        ...totals,
        deposited,
        collected,
        collectionRate: totals.totalToRender
          ? (totals.totalCollected / totals.totalToRender) * 100
          : 0,
      },
      daily: data.daily.map((row) => ({
        date: String(row.date),
        totalToRender: number(row.total_to_render),
        totalCollected: number(row.total_collected),
        difference: number(row.difference),
        liquidationCount: number(row.liquidation_count),
      })),
      paymentMethods: data.methods
        .map((row) => ({
          name: row.name,
          collected: number(row.collected),
          deposited: number(row.deposited),
          difference: number(row.difference),
          percentage: collected ? (number(row.collected) / collected) * 100 : 0,
        }))
        .filter((method) => Number(method.percentage.toFixed(1)) > 0),
      locations: data.locations.map((row) => ({
        localNumber: number(row.local_number),
        name: row.name,
        color: row.color,
        totalToRender: number(row.total_to_render),
        totalCollected: number(row.total_collected),
        difference: number(row.difference),
        liquidationCount: number(row.liquidation_count),
        compliantCount: number(row.compliant_count),
        pendingCount: number(row.pending_count),
        status: number(row.pending_count) === 0 ? "COMPLIANT" : "REVIEW",
      })),
      rankings: {
        locations: data.rankings.locations.map((row) => ({
          key: row.key,
          label: row.label,
          detail: row.detail,
          count: number(row.count),
          amount: number(row.amount),
        })),
        responsibles: data.rankings.responsibles.map((row) => ({
          key: row.key,
          label: row.label,
          detail: row.detail,
          count: number(row.count),
          amount: number(row.amount),
        })),
      },
    };
    this.logger.debug(
      `getDashboard completado: ${response.locations.length} sedes, ${response.totals.liquidationCount} cajas consolidadas`,
    );
    return response;
  }

  async getCashRegisters(
    dateFrom: string,
    dateTo: string,
    localNumber?: number,
  ): Promise<LiquidationCashRegister[]> {
    this.logger.debug(
      `getCashRegisters llamado con rango: ${dateFrom} a ${dateTo}, localNumber: ${localNumber ?? "todas"}`,
    );
    const start = Date.now();
    const rows = await this.repository.getCashRegisters(
      dateFrom,
      dateTo,
      localNumber,
    );
    this.logger.debug(
      `Consulta de cajas completada en ${Date.now() - start}ms: ${rows.length} registros`,
    );
    const number = (value: unknown) => Number(value ?? 0);
    return rows.map((row) => ({
      id: row.id,
      date: row.date,
      localNumber: number(row.local_number),
      location: row.location,
      cashRegisterCode: number(row.cash_register_code),
      responsible: row.responsible,
      totalToRender: number(row.total_to_render),
      totalCollected: number(row.total_collected),
      difference: number(row.difference),
      status: Math.abs(number(row.difference)) < 0.01 ? "COMPLIANT" : "REVIEW",
    }));
  }
}
