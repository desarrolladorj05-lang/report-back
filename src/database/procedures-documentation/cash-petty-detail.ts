import { defineParams, defineReturns } from "src/common/helpers/procedure.helpers";
import { Person } from "./cash-petty.report";

// 1. Entidad del movimiento
export interface MovementEntity {
  tipo: "EMPLOYEE" | "SUPPLIER" | "USER";
  id: string;
  nombre: string;
}

// 2. Documento asociado
export interface MovementDocument {
  tipo: string;     // name de sale_document_type
  numero: string | null;
}

// 3. Monto del movimiento
export interface MovementAmount {
  gravado: number;
  igv: number | null;
  total: number;
}

export interface MovementBalance {
  before: number;
  after: number;
}

// 4. Movimiento unificado (ingresos + egresos)
export interface CashPettyMovement {
  id: string;
  fecha: string;    // "mismo formato que created_at"
  created_at: string; 
  updated_at: string | null;
  status: number;   // Código numérico (40001 | 40002)
  tipo_movimiento: "INCOME" | "EXPENSE";
  tipo: string;     // name de general_param
  entidad: MovementEntity | null;
  documento: MovementDocument | null;
  monto: MovementAmount;
  observaciones: string | null;
  balance: MovementBalance;
}

// 5. Totales de la caja
export interface CashPettyTotals {
  monto_apertura: number | null;
  total_ingresos: number | null;
  total_egresos: number | null;
  total_reposiciones: number | null;
  saldo_actual: number | null;
  base_reposicion: number | null;
  diferencia_reposicion: number | null;
}

// 6. Caja chica (detalle completo)
export interface CashPettyDetail {
  id: string;
  code: string;
  descripcion: string | null;
  periodo: string;
  fecha_apertura: string; // "YYYY-MM-DD"
  fecha_cierre: string | null;
  responsable: Person;  
  totales: CashPettyTotals;
  estado: number;         // Código numérico
}

// 7. Información de la sede
export interface CashPettyDetailSede {
  idlocal: string;
  local_nombre: string;
}

// 8. Resultado del procedimiento
export interface CashPettyDetailResult {
  sede: CashPettyDetailSede;
  caja: CashPettyDetail;
  movimientos: CashPettyMovement[];
}

// 9. Definición del procedimiento
export const CashPettyDetailProcedure = {
  CASH_PETTY_DETAIL: {
    name: "sp_cash_petty_detail",
    params: defineParams<{
      p_cash_petty_id: string; // UUID
    }>(),
    returns: defineReturns<CashPettyDetailResult>(),
    paramOrder: ["p_cash_petty_id"],
  },
};