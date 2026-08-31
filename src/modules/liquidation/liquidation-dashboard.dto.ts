import { Transform, Type } from "class-transformer";
import { IsDateString, IsInt, IsOptional, Max, Min } from "class-validator";

export class LiquidationDashboardDto {
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
