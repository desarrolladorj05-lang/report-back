import { Transform, Type } from "class-transformer";
import { IsNotEmpty, IsNumber, IsString, IsUUID, Max, Min } from "class-validator";

export class CashPettyReportDto {
  @Type(() => Number)
  @IsNumber({}, { message: "El año debe ser numérico" })
  @Min(2000, { message: "El año mínimo es 2000" })
  @Max(new Date().getFullYear(), {
    message: `El año no puede ser mayor a ${new Date().getFullYear()}`,
  })
  year: number;

  @Type(() => Number)
  @IsNumber({}, { message: "El mes debe ser numérico" })
  @Min(1, { message: "El mes mínimo es 1" })
  @Max(12, { message: "El mes máximo es 12" })
  month: number;
}

export class CashPettyDetailDto {
  @IsNotEmpty({ message: "El ID es obligatorio" })
  @IsUUID("4", { message: "El ID debe ser un UUID válido" })
  id: string;
}