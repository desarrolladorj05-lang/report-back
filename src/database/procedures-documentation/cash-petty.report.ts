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
  fecha_inicio: string;			// "DD/MM/YYYY"
  fecha_fin: string;    		// "DD/MM/YYYY"
  sedes: SedePeriodReport[];
}

// 5. Definición del procedimiento
export const CashPettyReportProcedure = {
  CASH_PETTY_REPORT: {
    name: "sp_cash_petty_first_by_local",
    params: defineParams<{
      p_fecha_inicio: string; // Formato 'DD/MM/YYYY'
      p_fecha_fin: string; // Formato 'DD/MM/YYYY'
    }>(),
    returns: defineReturns<CashPettyReportResult>(),
    paramOrder: ["p_fecha_inicio", "p_fecha_fin"],
  },
};