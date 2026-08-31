import { Injectable } from "@nestjs/common";
import { TenantDataSourceFactory } from "src/config/tenancy/tenant-ds.factory";
import {
  LiquidationDashboardProcedure,
  LiquidationDashboardProcedureResult,
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
}
