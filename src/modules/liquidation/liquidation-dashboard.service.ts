import { BadRequestException, Injectable, Logger } from "@nestjs/common";
import { LiquidationDashboardRepository } from "./liquidation-dashboard.repository";
import {
  LiquidationCashRegister,
  LiquidationDashboardResponse,
} from "./liquidation-dashboard.types";
import { AuthzContext } from "src/auth/authz.types";

@Injectable()
export class LiquidationDashboardService {
  private readonly logger = new Logger(LiquidationDashboardService.name);

  constructor(private readonly repository: LiquidationDashboardRepository) {}

  async getDashboardForScope(
    dateFrom: string,
    dateTo: string,
    requestedLocal: number | undefined,
    context: AuthzContext,
  ) {
    if (requestedLocal !== undefined || context.hasAllLocals) {
      return this.getDashboard(dateFrom, dateTo, requestedLocal);
    }
    const reports = await Promise.all(
      context.locals.map((local) =>
        this.getDashboard(dateFrom, dateTo, local.number),
      ),
    );
    return this.mergeDashboards(reports, dateFrom, dateTo);
  }

  async getCashRegistersForScope(
    dateFrom: string,
    dateTo: string,
    requestedLocal: number | undefined,
    context: AuthzContext,
  ) {
    if (requestedLocal !== undefined || context.hasAllLocals) {
      return this.getCashRegisters(dateFrom, dateTo, requestedLocal);
    }
    const results = await Promise.all(
      context.locals.map((local) =>
        this.getCashRegisters(dateFrom, dateTo, local.number),
      ),
    );
    return results.flat();
  }

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
        .getPeriodTotals(previousDateFrom, previousDateTo, localNumber)
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
    const previousTotals = {
      totalToRender: number(previousData.total_to_render),
      totalCollected: number(previousData.total_collected),
      difference: number(previousData.difference),
      liquidationCount: number(previousData.liquidation_count),
      compliantCount: number(previousData.compliant_count),
      pendingCount: number(previousData.pending_count),
    };
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
      depositReconciliation: data.depositReconciliation.map((row) => {
        const cashCollected = number(row.cash_collected);
        const cardCollected = number(row.card_collected);
        const totalCollected = cashCollected + cardCollected;
        const depositedAmount = number(row.deposited);
        const depositCount = number(row.deposit_count);
        const difference = totalCollected - depositedAmount;
        return {
          date: String(row.date),
          cashCollected,
          cardCollected,
          totalCollected,
          deposited: depositedAmount,
          depositCount,
          difference,
          status:
            depositCount <= 0
              ? ("PENDING" as const)
              : Math.abs(depositedAmount - totalCollected) < 0.01
                ? ("DEPOSITED" as const)
                : ("PARTIAL" as const),
          locations: (row.locations ?? []).map((location) => {
            const locationCash = number(location.cashCollected);
            const locationCard = number(location.cardCollected);
            const locationTotal = locationCash + locationCard;
            const locationDeposited = number(location.deposited);
            const locationDepositCount = number(location.depositCount);
            return {
              localNumber: number(location.localNumber),
              localName: location.localName,
              cashCollected: locationCash,
              cardCollected: locationCard,
              totalCollected: locationTotal,
              deposited: locationDeposited,
              depositCount: locationDepositCount,
              difference: locationTotal - locationDeposited,
              cashRegisters: (location.cashRegisters ?? []).map(
                (cashRegister) => {
                  const cash = number(cashRegister.cashCollected);
                  const card = number(cashRegister.cardCollected);
                  const cashRegisterCollected = cash + card;
                  const cashDeposited = number(cashRegister.cashDeposited);
                  const cardDeposited = number(cashRegister.cardDeposited);
                  const cashRegisterDeposited = number(
                    cashRegister.deposited,
                  );
                  const cashRegisterDepositCount = number(
                    cashRegister.depositCount,
                  );
                  return {
                    id: String(cashRegister.id),
                    cashRegisterCode: number(
                      cashRegister.cashRegisterCode,
                    ),
                    responsible: cashRegister.responsible,
                    cashCollected: cash,
                    cardCollected: card,
                    totalCollected: cashRegisterCollected,
                    cashDeposited,
                    cardDeposited,
                    deposited: cashRegisterDeposited,
                    depositCount: cashRegisterDepositCount,
                    difference:
                      cashRegisterCollected - cashRegisterDeposited,
                    status:
                      cashRegisterDepositCount <= 0
                        ? ("PENDING" as const)
                        : Math.abs(
                              cashRegisterDeposited - cashRegisterCollected,
                            ) < 0.01
                          ? ("DEPOSITED" as const)
                          : ("PARTIAL" as const),
                  };
                },
              ),
            };
          }),
        };
      }),
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

  private mergeDashboards(
    reports: LiquidationDashboardResponse[],
    dateFrom: string,
    dateTo: string,
  ): LiquidationDashboardResponse {
    if (reports.length === 0) {
      throw new BadRequestException("El usuario no tiene sedes asignadas");
    }
    if (reports.length === 1) return reports[0];

    const sum = (values: number[]) => values.reduce((total, value) => total + value, 0);
    const mergeRows = <T extends { [key: string]: any }>(
      rows: T[],
      key: keyof T,
      numericFields: Array<keyof T>,
    ) => Array.from(rows.reduce((map, row) => {
      const id = String(row[key]);
      const current = map.get(id) ?? { ...row };
      if (map.has(id)) numericFields.forEach((field) => {
        (current as Record<string, any>)[String(field)] =
          Number(current[field] ?? 0) + Number(row[field] ?? 0);
      });
      map.set(id, current);
      return map;
    }, new Map<string, T>()).values());

    const totals = {
      totalToRender: sum(reports.map((r) => r.totals.totalToRender)),
      totalCollected: sum(reports.map((r) => r.totals.totalCollected)),
      difference: sum(reports.map((r) => r.totals.difference)),
      deposited: sum(reports.map((r) => r.totals.deposited)),
      collected: sum(reports.map((r) => r.totals.collected)),
      liquidationCount: sum(reports.map((r) => r.totals.liquidationCount)),
      compliantCount: sum(reports.map((r) => r.totals.compliantCount)),
      pendingCount: sum(reports.map((r) => r.totals.pendingCount)),
      collectionRate: 0,
    };
    totals.collectionRate = totals.totalToRender
      ? (totals.totalCollected / totals.totalToRender) * 100
      : 0;
    const previous = {
      totalToRender: sum(reports.map((r) => r.comparison.totalToRender)),
      totalCollected: sum(reports.map((r) => r.comparison.totalCollected)),
      difference: sum(reports.map((r) => r.comparison.difference)),
      liquidationCount: sum(reports.map((r) => r.comparison.liquidationCount)),
      pendingCount: sum(reports.map((r) => r.comparison.pendingCount)),
    };
    const change = (current: number, prior: number) =>
      prior === 0 ? (current === 0 ? 0 : 100) : ((current - prior) / Math.abs(prior)) * 100;
    const methods = mergeRows(
      reports.flatMap((r) => r.paymentMethods),
      "name",
      ["collected", "deposited", "difference"],
    ).map((method) => ({
      ...method,
      percentage: totals.collected ? (method.collected / totals.collected) * 100 : 0,
    }));
    const daily = mergeRows(
      reports.flatMap((r) => r.daily),
      "date",
      ["totalToRender", "totalCollected", "difference", "liquidationCount"],
    ).sort((a, b) => a.date.localeCompare(b.date));
    const reconciliation = mergeRows(
      reports.flatMap((r) => r.depositReconciliation),
      "date",
      ["cashCollected", "cardCollected", "totalCollected", "deposited", "depositCount", "difference"],
    ).map((day) => ({
      ...day,
      locations: reports.flatMap((r) =>
        r.depositReconciliation.find((item) => item.date === day.date)?.locations ?? [],
      ),
      status: day.depositCount <= 0
        ? ("PENDING" as const)
        : Math.abs(day.deposited - day.totalCollected) < 0.01
          ? ("DEPOSITED" as const)
          : ("PARTIAL" as const),
    }));

    return {
      period: reports[0].period,
      comparison: {
        period: reports[0].comparison.period,
        ...previous,
        totalToRenderChange: change(totals.totalToRender, previous.totalToRender),
        totalCollectedChange: change(totals.totalCollected, previous.totalCollected),
        differenceChange: change(totals.difference, previous.difference),
        liquidationCountChange: change(totals.liquidationCount, previous.liquidationCount),
        pendingCountChange: change(totals.pendingCount, previous.pendingCount),
      },
      totals,
      daily,
      paymentMethods: methods,
      depositReconciliation: reconciliation,
      locations: reports.flatMap((r) => r.locations),
      rankings: {
        locations: reports.flatMap((r) => r.rankings.locations),
        responsibles: mergeRows(
          reports.flatMap((r) => r.rankings.responsibles),
          "key",
          ["count", "amount"],
        ).sort((a, b) => b.amount - a.amount),
      },
    };
  }
}
