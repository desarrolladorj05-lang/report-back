import { IsDateString } from "class-validator";

export class CommercialSalesReportDto {
  @IsDateString()
  dateFrom: string;

  @IsDateString()
  dateTo: string;
}
