import {
  defineParams,
  defineReturns,
} from "src/common/helpers/procedure.helpers";

// Detalle por isla/manguera
export interface ContometroDetalle {
  side_name: string;
  hose_name: string;
  initial_contometer: number;
  final_contometer: number;
  volume_contometer: number;
  volume_sales: number;
  serafin_volume: number;
  difference_volume: number;
}

// Agrupado por producto
export interface ContometroByProduct {
  id_producto: number;
  product_name: string;
  price: number;
  detalle: ContometroDetalle[];
}

// Respuesta completa del SP
export interface ReporteContometroResponse {
  id_turno: number;
  turno: string;
  fecha: string;
  productos: ContometroByProduct[];
}

export const ReportContometroByProductProcedure = {
  REPORTE_CONTOMETRO_BY_PRODUCT: {
    name: "sp_report_contometer_by_product",
    params: defineParams<{
      p_id_local: number;
      p_fecha_busqueda: string;
      p_id_turno: number | null;
      p_id_producto: number | null;
    }>(),
    returns: defineReturns<ReporteContometroResponse>(),
    paramOrder: [
      "p_id_local",
      "p_fecha_busqueda",
      "p_id_turno",
      "p_id_producto",
    ],
  },
};
