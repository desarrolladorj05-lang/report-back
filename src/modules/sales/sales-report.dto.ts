import { Transform, Type } from "class-transformer";
import {
  IsString,
  IsNotEmpty,
  IsNumber,
  IsPositive,
  IsOptional,
} from "class-validator";
import { DateFormatter } from "src/common/helpers/date-formatter.util";

export class BaseReportDto {
  @IsNotEmpty({ message: "La fecha es obligatoria" })
  @IsString()
  @Transform(({ value }) => value?.trim())
  date: string;
}

export class ReportBySedeDto extends BaseReportDto {
  @IsOptional() // <-- CAMBIO CLAVE: Ahora el ID puede no venir
  @Transform(({ value }) => {
    if (value === null || value === undefined || value === "") return undefined;
    const parsed = parseInt(value, 10);
    return isNaN(parsed) ? value : parsed;
  })
  @IsNumber({}, { message: "El ID del local debe ser un número" })
  @IsPositive({ message: "El ID del local debe ser un valor positivo" })
  id_local?: number;
}

// Mantienes tus alias para no romper los controladores
export class ManagmentReportDto extends BaseReportDto {}
export class SalesBySedeDto extends ReportBySedeDto {}
export class FuelReportBySedeDto extends ReportBySedeDto {}
export class AllClientReportsDto extends ReportBySedeDto {}
