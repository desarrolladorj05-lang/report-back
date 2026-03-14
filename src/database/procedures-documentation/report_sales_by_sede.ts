import { defineParams, defineReturns } from "../../common/helpers/procedure.helpers";

//Detalle de conceptos (Serafín, Consumo Interno, Créditos, etc.)
export interface ConceptoDetalle {
  concepto: string;
  monto: string; 
}

// Detalle de métodos de pago
export interface PagoDetalle {
  metodo: string;
  monto: string;
}

// Estructura de cada sección (Venta Bruta, Venta Neta, etc.)
export interface SeccionReporte {
  titulo: string;
  total: string;
  detalle?: ConceptoDetalle[] | PagoDetalle[]; 
}

// Estructura de cada bloque (Turnos o TOTAL GENERAL)
export interface BloqueReporteSede {
  nombre_bloque: string;
  secciones: SeccionReporte[];
}

// 5. Definición del objeto del procedimiento
export const SalesBySedeProcedure = {
  REPORTE_VENTAS_BY_SEDE: {
    name: "sp_reporte_ventas_by_sede",
    params: defineParams<{
      p_id_local: number;
      p_fecha_busqueda: string; // Formato 'DD/MM/YYYY'
    }>(),
    // Retorna un JSONB que es un array de BloqueReporteSede
    returns: defineReturns<BloqueReporteSede[]>(),
    paramOrder: ["p_id_local", "p_fecha_busqueda"],
  },
};