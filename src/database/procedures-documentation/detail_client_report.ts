import {
  defineParams,
  defineReturns,
} from "../../common/helpers/procedure.helpers"; // Ajusta la ruta según tu proyecto

// Interfaz base para todas las filas (Créditos, Canjes, etc.)
export interface ClienteBaseDetalle {
  nro_documento: string;
  nombre_cliente: string;
  placa: string;
  chofer: string;
  nro_comprobante: string;
  producto: string;
  cantidad: number;
  importe: number;
}

// Interfaz específica para descuentos (incluye la columna extra)
export interface ClienteDescuentoDetalle extends ClienteBaseDetalle {
  monto_descuento: number;
}

// Estructura del JSONB que devuelve el SP
export interface ReporteDetalleClientesResponse {
  descuentos: ClienteDescuentoDetalle[];
  transferencias: ClienteBaseDetalle[];
  creditos: ClienteBaseDetalle[];
  adelantos: ClienteBaseDetalle[];
  consumo_interno: ClienteBaseDetalle[];
  canjes: ClienteBaseDetalle[];
}

// Definición del objeto del procedimiento
export const ClientReportsProcedure = {
  GET_ALL_CLIENT_REPORTS: {
    name: "sp_get_all_client_reports_by_date",
    params: defineParams<{
      p_id_local: number;
      p_fecha_busqueda: string;
    }>(),
    returns: defineReturns<ReporteDetalleClientesResponse>(),
    paramOrder: ["p_id_local", "p_fecha_busqueda"],
  },
};
