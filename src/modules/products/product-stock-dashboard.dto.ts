import { Type } from "class-transformer";
import { IsDateString, IsInt, IsOptional, Min } from "class-validator";

export class ProductStockDashboardDto {
  @IsDateString()
  dateFrom: string;

  @IsDateString()
  dateTo: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  localNumber?: number;
}
