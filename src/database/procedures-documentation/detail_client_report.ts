import {
  defineParams,
  defineReturns,
} from "../../common/helpers/procedure.helpers";

// Interfaz base para todas las filas
export interface ClienteBaseDetalle {
  nro_documento: string;
  nombre_cliente: string;
  placa: string;
  chofer: string;
  nro_comprobante: string;
  producto: string;
  cantidad: string;
  importe: string;
}

// Interfaz específica para descuentos
export interface ClienteDescuentoDetalle extends ClienteBaseDetalle {
  monto_descuento: string | null;
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
      p_id_local: number | null;
      p_fecha_busqueda: string;
      p_id_concepto?: string | number | null;
      p_id_turno?: string | number | null;
    }>(),
    returns: defineReturns<ReporteDetalleClientesResponse>(),
    paramOrder: [
      "p_id_local",
      "p_fecha_busqueda",
      "p_id_concepto",
      "p_id_turno",
    ],
  },
};
