import { Injectable } from "@nestjs/common";
import { validateReportDateRange } from "src/common/helpers/report-date-range.helper";
import { CommercialSalesRepository } from "./commercial-sales.repository";

@Injectable()
export class CommercialSalesService {
  constructor(private readonly repository: CommercialSalesRepository) {}

  async getReport(dateFrom: string, dateTo: string, localIds?: string[]) {
    const { days } = validateReportDateRange(dateFrom, dateTo);
    const rows = await this.repository.getReport(dateFrom, dateTo, localIds);
    const number = (value: unknown) => Number(value ?? 0);
    const normalized = rows.map((row) => ({
      date:
        row.sale_date instanceof Date
          ? row.sale_date.toISOString().slice(0, 10)
          : String(row.sale_date).slice(0, 10),
      localId: row.local_id,
      localNumber: number(row.local_number),
      localName: row.local_name,
      localColor: row.local_color,
      localOrder: number(row.local_order),
      productId: number(row.product_id),
      productName: row.product_name,
      amount: number(row.amount),
      gallons: number(row.gallons),
    }));
    const locals = Array.from(
      new Map(
        normalized.map((row) => [
          row.localId,
          {
            id: row.localId,
            number: row.localNumber,
            name: row.localName,
            color: row.localColor,
            order: row.localOrder,
          },
        ]),
      ).values(),
    ).sort((left, right) => left.order - right.order);
    const products = Array.from(
      new Map(
        normalized.map((row) => [
          row.productId,
          { id: row.productId, name: row.productName },
        ]),
      ).values(),
    ).sort((left, right) => left.name.localeCompare(right.name));

    return {
      period: { dateFrom, dateTo, days },
      locals,
      products,
      rows: normalized,
    };
  }
}
