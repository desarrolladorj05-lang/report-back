import { defineParams, defineReturns } from "src/common/helpers/procedure.helpers";

// 1. Detalles de responsable de la caja
export interface Person {
  id: string | null;
  first_name: string;
  last_name: string;
  full_name: string;
}

// 2. Detalles de caja chica (registro individual) en array "cajas"
export interface CashPettyPeriodReport {
  id: string;
  code: string;
  periodo: string;
  fecha_apertura: string;   // "YYYY-MM-DD"
  fecha_cierre: string | null;
  responsable: Person;
  monto_apertura: number;
  total_ingresos: number;
  total_egresos: number;
  saldo: number;
  estado: number;						// Código numérico
}

// 3. Agrupación de caja chica por sede
export interface SedePeriodReport {
  idlocal: string; 					// UUID
  local_nombre: string;
  color: string;
  cajas: CashPettyPeriodReport[]; 
}

// 4. Respuesta principal del procedimiento
export interface CashPettyReportResult {
  periodo: string;						// "YYYY-MM"
  sedes: SedePeriodReport[];
}

// 5. Definición del procedimiento
export const CashPettyReportProcedure = {
  CASH_PETTY_REPORT: {
    name: "sp_cash_petty_report_by_period",
    params: defineParams<{
      p_year: number;
      p_month: number;
    }>(),
    returns: defineReturns<CashPettyReportResult>(),
    paramOrder: ["p_year", "p_month"],
  },
};