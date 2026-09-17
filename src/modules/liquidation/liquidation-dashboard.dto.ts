import { Transform, Type } from "class-transformer";
import {
  ArrayUnique,
  IsArray,
  IsDateString,
  IsInt,
  IsOptional,
  Min,
} from "class-validator";

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

  @IsOptional()
  @Transform(({ value }) => {
    const values = Array.isArray(value) ? value : String(value).split(",");
    return values.filter(Boolean).map(Number);
  })
  @IsArray()
  @ArrayUnique()
  @IsInt({ each: true })
  @Min(1, { each: true })
  localNumbers?: number[];
}
