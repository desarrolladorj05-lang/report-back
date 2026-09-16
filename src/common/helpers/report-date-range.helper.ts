import { BadRequestException } from "@nestjs/common";

export const MAX_REPORT_RANGE_DAYS = 31;

export function validateReportDateRange(dateFrom: string, dateTo: string) {
  const from = new Date(`${dateFrom}T00:00:00Z`);
  const to = new Date(`${dateTo}T00:00:00Z`);
  if (from > to) {
    throw new BadRequestException(
      "La fecha inicial no puede ser posterior a la fecha final",
    );
  }
  const days = Math.floor((to.getTime() - from.getTime()) / 86400000) + 1;
  if (days > MAX_REPORT_RANGE_DAYS) {
    throw new BadRequestException(
      `El rango máximo permitido es de ${MAX_REPORT_RANGE_DAYS} días`,
    );
  }
  return { from, to, days };
}
