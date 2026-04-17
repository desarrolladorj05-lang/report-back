import { Transform } from "class-transformer";
import { IsNotEmpty, IsString, IsUUID } from "class-validator";

export class CashPettyReportDto {
  @IsNotEmpty({ message: "La fecha inicio es obligatoria" })
  @IsString()
  @Transform(({ value }) => value?.trim())
  fecha_inicio: string;

  @IsNotEmpty({ message: "La fecha fin es obligatoria" })
  @IsString()
  @Transform(({ value }) => value?.trim())
  fecha_fin: string;
}

export class CashPettyDetailDto {
  @IsNotEmpty({ message: "El ID es obligatorio" })
  @IsUUID("4", { message: "El ID debe ser un UUID válido" })
  id: string;
}