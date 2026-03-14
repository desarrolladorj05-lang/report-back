import { Transform } from "class-transformer";
import { IsString, IsNotEmpty, Matches, IsNumber, IsPositive } from "class-validator";
import { DateFormatter } from "src/common/helpers/date-formatter.util";
export class ManagmentReportDto {
  @IsNotEmpty({ message: "La fecha es obligatoria" })
  @IsString()
  @Transform(({ value }) => value?.trim()) 
  @Transform(({ value }) => {
    // Validar formato antes de aceptar el valor
    if (!DateFormatter.isValidFormat(value)) {
      throw new Error("La fecha debe tener el formato DD/MM/YYYY");
    }
    return value;
  })
  date: string;
}

export class SalesBySedeDto {
  @IsNotEmpty({ message: "El ID del local es obligatorio" })
  @Transform(({ value }) => {
    const parsed = parseInt(value, 10);
    return isNaN(parsed) ? value : parsed; // Intentamos convertir a número
  })
  @IsNumber({}, { message: "El ID del local debe ser un número" })
  @IsPositive({ message: "El ID del local debe ser un valor positivo" })
  id_local: number;

  @IsNotEmpty({ message: "La fecha es obligatoria" })
  @IsString()
  @Transform(({ value }) => value?.trim())
  @Transform(({ value }) => {
    if (value && !DateFormatter.isValidFormat(value)) {

      return value; 
    }
    return value;
  })
  date: string;
}

export class FuelReportBySedeDto {
  @IsNotEmpty({ message: "El ID del local es obligatorio" })
  @Transform(({ value }) => {
    const parsed = parseInt(value, 10);
    return isNaN(parsed) ? value : parsed;
  })
  @IsNumber({}, { message: "El ID del local debe ser un número" })
  @IsPositive({ message: "El ID del local debe ser un valor positivo" })
  id_local: number;

  @IsNotEmpty({ message: "La fecha es obligatoria" })
  @IsString()
  @Transform(({ value }) => value?.trim())
  @Transform(({ value }) => {

    if (value && !DateFormatter.isValidFormat(value)) {
      return value; 
    }
    return value;
  })
  date: string;
}