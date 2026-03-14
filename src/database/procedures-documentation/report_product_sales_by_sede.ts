import { defineParams, defineReturns } from "../../common/helpers/procedure.helpers";

// Detalle individual de cada producto (ej. Gasohol, Diesel)
export interface ProductoCombustibleDetalle {
  monto: string;
  cantidad: number;
  producto: string;
}

// Estructura de cada bloque de turno o el Total General
export interface BloqueReporteCombustible {
  turno: string;
  total_monto: string;
  total_cantidad: number;
  detalle_productos: ProductoCombustibleDetalle[];
}

// Respuesta principal del procedimiento
export interface ReporteCombustiblesResponse {
  nombre_sede: string;
  categoria: string;
  reporte_por_turnos: BloqueReporteCombustible[];
}

// Definición del objeto del procedimiento
export const SaleFuelReportProcedure = {
  REPORTE_COMBUSTIBLES_BY_SEDE: {
    name: "sp_reporte_combustibles_by_sede",
    params: defineParams<{
      p_id_local: number;
      p_fecha_busqueda: string; 
    }>(),
    returns: defineReturns<ReporteCombustiblesResponse>(),
    paramOrder: ["p_id_local", "p_fecha_busqueda"],
  },
};