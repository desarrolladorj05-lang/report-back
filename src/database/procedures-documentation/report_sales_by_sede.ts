import {
  defineParams,
  defineReturns,
} from "../../common/helpers/procedure.helpers";

// Detalle genérico para conceptos (Serafín, Consumo) y métodos (Efectivo, Visa)
export interface DetalleItem {
  id?: number | string;
  concepto?: string; // Usado en Venta Bruta/Neta
  metodo?: string; // Usado en Venta Contada
  monto: string;
}

// Estructura de cada secció
export interface SeccionReporte {
  titulo: string;
  total: string;
  detalle?: DetalleItem[];
  recaudado_fisico?: DetalleItem[];
}

// Estructura de cada bloque (Turnos o TOTAL GENERAL)
export interface BloqueReporteSede {
  nombre_bloque: string;
  total_operaciones: number;
  ticket_promedio: string;
  variacion: string;
  secciones: SeccionReporte[];
}

// Estructura raíz que devuelve el SP (resultado jsonb)
export interface RespuestaReporteSede {
  nombre_sede: string;
  reporte: BloqueReporteSede[];
}

// Definición del objeto del procedimiento
export const SalesBySedeProcedure = {
  REPORTE_VENTAS_BY_SEDE: {
    name: "sp_reporte_ventas_by_sede",
    params: defineParams<{
      p_id_local: number | null;
      p_fecha_busqueda: string;
    }>(),
    // El retorno ahora es una Unión de Tipos para ser honestos con el SP
    returns: defineReturns<RespuestaReporteSede | RespuestaReporteSede[]>(),
    paramOrder: ["p_id_local", "p_fecha_busqueda"],
  },
};
