import {
  defineParams,
  defineReturns,
} from "../../common/helpers/procedure.helpers";

// 1. Detalle de turnos (se mantiene igual)
export interface TurnoDetalle {
  turno: string;
  monto: number;
  porc_del_local: number;
}

// 2. Punto de datos para la gráfica de líneas (se mantiene igual)
export interface HistoricoVenta {
  fecha: string;
  venta: number;
}

// 3. Estructura para el bloque de Analytics por Sede
export interface AnalyticsSede {
  idlocal: number;
  local_nombre: string;
  color: string;
  total_acumulado_mes: number;
  serie_historica: HistoricoVenta[];
}

// 4. Cada sede en el array "sedes"
export interface SedeReporte {
  idlocal: number;
  local_nombre: string;
  color: string;
  monto_hoy: number;
  monto_ayer: number;
  porc_variacion_diaria: number;
  detalles_turnos: TurnoDetalle[];
}

// 5. Estructura completa del JSON que retorna el SP (ACTUALIZADO)
export interface SalesReportResult {
  fecha_operativa: string;
  venta_total_todas_sedes: number;
  variacion_total_global: number;
  total_acumulado_global:number;
  analytics_general: HistoricoVenta[]; 
  sedes: SedeReporte[];
  analytics: AnalyticsSede[];
}

// 6. Definición del procedimiento
export const SalesReportProcedure = {
  MANAGMENT_REPORT_SALES: {
    name: "sp_managment_report_sales",
    params: defineParams<{
      p_fecha_busqueda: string; // Formato 'DD/MM/YYYY'
    }>(),
    returns: defineReturns<SalesReportResult>(),
    paramOrder: ["p_fecha_busqueda"],
  },
};