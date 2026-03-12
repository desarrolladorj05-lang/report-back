import { defineParams, defineReturns } from "../../common/helpers/procedure.helpers";
// 1. Definimos la interfaz para el detalle de turnos
export interface TurnoDetalle {
  turno: string;
  monto: number;
  porc_del_local: number;
}
// 2. Definimos la interfaz para cada sede en el array "sedes"
export interface SedeReporte {
  local_nombre: string;
  monto_hoy: number;
  monto_ayer: number;
  porc_variacion_diaria: number;
  detalles_turnos: TurnoDetalle[];
}
// 3. Definimos la estructura completa del JSON que retorna el SP
export interface SalesReportResult {
  fecha_operativa: string;
  venta_total_todas_sedes: number;
  sedes: SedeReporte[];
}
// 4. Definimos el objeto del procedimiento
export const SalesReportProcedure = {
  MANAGMENT_REPORT_SALES: {
    name: "sp_managment_report_sales",
    params: defineParams<{
      p_fecha_busqueda: string; // Formato 'DD/MM/YYYY'
    }>(),
    // El SP retorna una tabla con una columna JSON, por eso mapeamos a la interfaz
    returns: defineReturns<SalesReportResult>(),
    paramOrder: ["p_fecha_busqueda"],
  },
};