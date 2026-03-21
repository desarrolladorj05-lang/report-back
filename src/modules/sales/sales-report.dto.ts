import { Transform } from "class-transformer";
import { IsString, IsNotEmpty, IsNumber, IsPositive } from "class-validator";
import { DateFormatter } from "src/common/helpers/date-formatter.util";

/**
 * DTO Base para reportes que solo requieren fecha (como el gerencial)
 */
export class BaseReportDto {
  @IsNotEmpty({ message: "La fecha es obligatoria" })
  @IsString()
  @Transform(({ value }) => value?.trim())
  @Transform(({ value }) => {
    if (value && !DateFormatter.isValidFormat(value)) {
      // Dejamos que el Service o el pipe de validación maneje el error 
      // o lanzamos el error aquí mismo.
      return value; 
    }
    return value;
  })
  date: string;
}

/**
 * DTO para todos los reportes que se filtran por SEDE y FECHA
 * (Ventas por sede, Combustibles, Descuentos, etc.)
 */
export class ReportBySedeDto extends BaseReportDto {
  @IsNotEmpty({ message: "El ID del local es obligatorio" })
  @Transform(({ value }) => {
    const parsed = parseInt(value, 10);
    return isNaN(parsed) ? value : parsed;
  })
  @IsNumber({}, { message: "El ID del local debe ser un número" })
  @IsPositive({ message: "El ID del local debe ser un valor positivo" })
  id_local: number;
}

// Ahora tus DTOs antiguos pueden ser simples alias o eliminarse
export class ManagmentReportDto extends BaseReportDto {}
export class SalesBySedeDto extends ReportBySedeDto {}
export class FuelReportBySedeDto extends ReportBySedeDto {}
export class AllClientReportsDto extends ReportBySedeDto {}
