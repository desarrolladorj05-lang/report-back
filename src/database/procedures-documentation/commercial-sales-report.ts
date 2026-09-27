import {
  defineParams,
  defineReturns,
} from "src/common/helpers/procedure.helpers";

export interface CommercialSalesReportRow {
  sale_date: string | Date;
  local_id: string;
  local_number: number;
  local_name: string;
  local_color: string;
  local_order: number;
  product_id: number;
  product_name: string;
  amount: number;
  gallons: number;
}

export const CommercialSalesReportProcedure = {
  COMMERCIAL_SALES_REPORT: {
    name: "sp_commercial_sales_report",
    params: defineParams<{
      p_date_from: string;
      p_date_to: string;
      p_local_ids: string[] | null;
    }>(),
    returns: defineReturns<CommercialSalesReportRow>(),
    paramOrder: ["p_date_from", "p_date_to", "p_local_ids"],
  },
};
