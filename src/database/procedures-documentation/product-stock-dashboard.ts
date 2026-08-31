import {
  defineParams,
  defineReturns,
} from "src/common/helpers/procedure.helpers";

export interface ProductStockDashboardProcedureResult {
  totals: Record<string, number>;
  daily: Record<string, unknown>[];
  products: Record<string, unknown>[];
  locations: Record<string, unknown>[];
  stockByLocation: Record<string, unknown>[];
  recentMovements: Record<string, unknown>[];
}

export const ProductStockDashboardProcedure = {
  PRODUCT_STOCK_DASHBOARD: {
    name: "sp_product_stock_dashboard",
    params: defineParams<{
      p_date_from: string;
      p_date_to: string;
      p_local_number: number | null;
    }>(),
    returns: defineReturns<ProductStockDashboardProcedureResult>(),
    paramOrder: ["p_date_from", "p_date_to", "p_local_number"],
  },
};
