import {
  IsOptional,
  IsEnum,
  IsDateString,
  IsString,
  IsInt,
  Min,
} from "class-validator";
import { Type } from "class-transformer";

export enum Intervalo {
  DIARIO = "diario",
  MENSUAL = "mensual",
}

export class SalesFilterDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  local?: number; // ej: 4 (por defecto)

  @IsOptional()
  @IsDateString()
  fechaInicio?: string; // YYYY-MM-DD

  @IsOptional()
  @IsDateString()
  fechaFin?: string; // YYYY-MM-DD

  @IsOptional()
  @IsString()
  productos?: string; // Nombres reales separados por coma, ej: "GASOHOL PREMIUM,DIESEL BS 550"

  @IsOptional()
  @IsString()
  turno?: string; // Valor real del turno, ej: "MAÑANA", "TARDE", "NOCHE"

  @IsOptional()
  @IsEnum(Intervalo)
  intervalo?: Intervalo; // "diario" | "mensual"
}
