import {
  defineParams,
  defineReturns,
} from "../../common/helpers/procedure.helpers";

export interface SalesReportResult {
  summary: {
    totalVentas: number;
    montoTotal: number;
  };
  details: Array<{
    fecha: string;
    turno: string;
    producto: string;
    monto: number;
    cantidad: number;
  }>;
}

export const ReportProcedure = {
  REPORT_DASHBOARD_VENTAS: {
    name: "sp_dashboard_ventas_full",
    params: defineParams<{
      p_local: number;
      p_desde: string;
      p_hasta: string;
    }>(),
    // Si el SP devuelve JSONB, definimos el tipo de retorno como el JSON
    returns: defineReturns<SalesReportResult>(),
    paramOrder: ["p_local", "p_desde", "p_hasta"],
  },
};
