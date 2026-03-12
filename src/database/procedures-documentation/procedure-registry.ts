import { ReportProcedure } from "./report.procedures";

export const procedureRegistry = {
  ...ReportProcedure,
} as const;

export { SalesReportResult } from "./report.procedures";

type ProcedureRegistry = typeof procedureRegistry;

export type ProcedureNameEnum =
  ProcedureRegistry[keyof ProcedureRegistry]["name"];

export type ProcedureParamMap = {
  [K in keyof ProcedureRegistry as ProcedureRegistry[K]["name"]]: ProcedureRegistry[K]["params"];
};

export type ProcedureReturnMap = {
  [K in keyof ProcedureRegistry as ProcedureRegistry[K]["name"]]: ProcedureRegistry[K]["returns"];
};

export const procedureParamOrder: {
  [K in ProcedureNameEnum]: (keyof ProcedureParamMap[K])[];
} = Object.fromEntries(
  Object.values(procedureRegistry).map((proc) => [
    proc.name,
    proc.paramOrder ?? Object.keys(proc.params),
  ]),
) as any;
