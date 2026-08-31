import {
  defineParams,
  defineReturns,
} from "src/common/helpers/procedure.helpers";

export interface LiquidationDashboardProcedureResult {
  daily: Array<{
    date: string;
    total_to_render: number;
    total_collected: number;
    difference: number;
    liquidation_count: number;
  }>;
  methods: Array<{
    name: string;
    collected: number;
    deposited: number;
    difference: number;
  }>;
  locations: Array<{
    local_number: number;
    name: string;
    color: string;
    sort_order: number;
    total_to_render: number;
    total_collected: number;
    difference: number;
    liquidation_count: number;
    compliant_count: number;
    pending_count: number;
  }>;
  rankings: {
    locations: LiquidationRankingProcedureRow[];
    responsibles: LiquidationRankingProcedureRow[];
  };
  cashRegisters: Array<{
    id: string;
    date: string;
    local_number: number;
    location: string;
    cash_register_code: number;
    responsible: string;
    total_to_render: number;
    total_collected: number;
    difference: number;
  }>;
}

export interface LiquidationRankingProcedureRow {
  key: string;
  label: string;
  detail?: string;
  count: number;
  amount: number;
}

export const LiquidationDashboardProcedure = {
  LIQUIDATION_DASHBOARD: {
    name: "sp_liquidation_dashboard",
    params: defineParams<{
      p_date_from: string;
      p_date_to: string;
      p_local_number: number | null;
      p_include_details: boolean;
    }>(),
    returns: defineReturns<LiquidationDashboardProcedureResult>(),
    paramOrder: [
      "p_date_from",
      "p_date_to",
      "p_local_number",
      "p_include_details",
    ],
  },
  LIQUIDATION_CASH_REGISTERS: {
    name: "sp_liquidation_cash_registers",
    params: defineParams<{
      p_date_from: string;
      p_date_to: string;
      p_local_number: number | null;
    }>(),
    returns:
      defineReturns<
        Pick<LiquidationDashboardProcedureResult, "cashRegisters">
      >(),
    paramOrder: ["p_date_from", "p_date_to", "p_local_number"],
  },
};
