import { IsArray, IsNumber, IsString, ValidateNested } from "class-validator";
import { Type } from "class-transformer";

export class SalesRowDto {
  @IsString()
  fecha: string;

  @IsString()
  turno: string;

  @IsString()
  producto: string;

  @IsNumber()
  monto: number;

  @IsNumber()
  cantidad: number;
}

export class SalesResponseDto {
  @IsNumber()
  count: number;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SalesRowDto)
  data: SalesRowDto[];
}

export class PointDto {
  @IsString()
  eje: string;

  @IsNumber()
  monto: number;

  @IsNumber()
  cantidad: number;
}

export class SeriesDto {
  @IsString()
  productName: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => PointDto)
  points: PointDto[];
}

export class GroupedSalesResponseDto {
  @IsString()
  intervalo: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SeriesDto)
  series: SeriesDto[];
}

export class FilterOptionsResponseDto {
  @IsArray()
  @IsString({ each: true })
  turnos: string[];

  @IsArray()
  @IsString({ each: true })
  productos: string[];
}
