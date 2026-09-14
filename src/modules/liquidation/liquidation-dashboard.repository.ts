import { Injectable } from "@nestjs/common";
import { TenantDataSourceFactory } from "src/config/tenancy/tenant-ds.factory";
import {
  LiquidationDashboardProcedure,
  LiquidationDashboardProcedureResult,
  LiquidationPeriodTotalsProcedureResult,
} from "src/database/procedures-documentation/liquidation-dashboard";
import { BaseRepository } from "src/database/repositories/base.repository";

@Injectable()
export class LiquidationDashboardRepository extends BaseRepository<any> {
  constructor(dsFactory: TenantDataSourceFactory) {
    super(Object as any, dsFactory);
  }

  async getDashboard(
    dateFrom: string,
    dateTo: string,
    localNumber?: number,
  ): Promise<LiquidationDashboardProcedureResult> {
    const result = await this.executeProcedure({
      name: LiquidationDashboardProcedure.LIQUIDATION_DASHBOARD.name,
      params: {
        p_date_from: dateFrom,
        p_date_to: dateTo,
        p_local_number: localNumber ?? null,
        p_include_details: false,
      },
    });

    const firstRow = result[0];
    const dashboard = firstRow
      ? (Object.values(firstRow)[0] as LiquidationDashboardProcedureResult)
      : undefined;

    return {
      daily: dashboard?.daily ?? [],
      methods: dashboard?.methods ?? [],
      depositReconciliation: dashboard?.depositReconciliation ?? [],
      locations: dashboard?.locations ?? [],
      rankings: dashboard?.rankings ?? { locations: [], responsibles: [] },
      cashRegisters: dashboard?.cashRegisters ?? [],
    };
  }

  async getCashRegisters(
    dateFrom: string,
    dateTo: string,
    localNumber?: number,
  ): Promise<LiquidationDashboardProcedureResult["cashRegisters"]> {
    const result = await this.executeProcedure({
      name: LiquidationDashboardProcedure.LIQUIDATION_CASH_REGISTERS.name,
      params: {
        p_date_from: dateFrom,
        p_date_to: dateTo,
        p_local_number: localNumber ?? null,
      },
    });
    const firstRow = result[0];
    const response = firstRow
      ? (Object.values(firstRow)[0] as Pick<
          LiquidationDashboardProcedureResult,
          "cashRegisters"
        >)
      : undefined;
    return response?.cashRegisters ?? [];
  }

  async getPeriodTotals(
    dateFrom: string,
    dateTo: string,
    localNumber?: number,
  ): Promise<LiquidationPeriodTotalsProcedureResult> {
    try {
      const rows = await this.executeProcedure({
        name: LiquidationDashboardProcedure.LIQUIDATION_PERIOD_TOTALS.name,
        params: {
          p_date_from: dateFrom,
          p_date_to: dateTo,
          p_local_number: localNumber ?? null,
        },
      });
      return (
        (rows[0] as LiquidationPeriodTotalsProcedureResult | undefined) ??
        this.emptyPeriodTotals()
      );
    } catch (error) {
      const databaseError = error as { code?: string };
      if (databaseError.code !== "42883") throw error;

      // Allows a rolling deploy while the optimized function is installed in tenants.
      const dashboard = await this.getDashboard(dateFrom, dateTo, localNumber);
      return dashboard.locations.reduce(
        (totals, row) => ({
          total_to_render:
            totals.total_to_render + Number(row.total_to_render ?? 0),
          total_collected:
            totals.total_collected + Number(row.total_collected ?? 0),
          difference: totals.difference + Number(row.difference ?? 0),
          liquidation_count:
            totals.liquidation_count + Number(row.liquidation_count ?? 0),
          compliant_count:
            totals.compliant_count + Number(row.compliant_count ?? 0),
          pending_count: totals.pending_count + Number(row.pending_count ?? 0),
        }),
        this.emptyPeriodTotals(),
      );
    }
  }

  private emptyPeriodTotals(): LiquidationPeriodTotalsProcedureResult {
    return {
      total_to_render: 0,
      total_collected: 0,
      difference: 0,
      liquidation_count: 0,
      compliant_count: 0,
      pending_count: 0,
    };
  }
}
