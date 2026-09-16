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

export interface ProductKardexProcedureResult {
  page: number;
  pageSize: number;
  total: number;
  rows: Record<string, unknown>[];
}

export interface FuelStockReportProcedureRow {
  local_id: string;
  local_name: string;
  warehouse_id: string;
  warehouse_name: string;
  tank_name: string;
  product_id: number;
  product_name: string;
  rows:
    | Array<{
        date: string;
        stockInitial: number;
        income: number;
        internalConsumption: number;
        warehouseTransfer: number;
        sales: number;
        externalSales: number;
        stockTheoretical: number;
        stockPhysical: number;
        differenceDay: number;
      }>
    | string;
}

export interface ProductLocalPresentationProcedureRow {
  id_local: string;
  color_hex: string;
  sort_order: number;
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
  PRODUCT_KARDEX: {
    name: "sp_product_kardex",
    params: defineParams<{
      p_date_from: string;
      p_date_to: string;
      p_product_id: number;
      p_page: number;
      p_page_size: number;
    }>(),
    returns: defineReturns<ProductKardexProcedureResult>(),
    paramOrder: [
      "p_date_from",
      "p_date_to",
      "p_product_id",
      "p_page",
      "p_page_size",
    ],
  },
  FUEL_STOCK_REPORT: {
    name: "get_fuel_stock_detailed_groups",
    params: defineParams<{
      p_created_from: string;
      p_created_to: string;
      p_local_ids: string[] | null;
      p_warehouse_ids: string[] | null;
      p_product_ids: number[] | null;
    }>(),
    returns: defineReturns<FuelStockReportProcedureRow>(),
    paramOrder: [
      "p_created_from",
      "p_created_to",
      "p_local_ids",
      "p_warehouse_ids",
      "p_product_ids",
    ],
  },
  PRODUCT_LOCAL_PRESENTATION: {
    name: "sp_product_local_presentation",
    params: defineParams<{
      p_local_ids: string[];
    }>(),
    returns: defineReturns<ProductLocalPresentationProcedureRow>(),
    paramOrder: ["p_local_ids"],
  },
};
