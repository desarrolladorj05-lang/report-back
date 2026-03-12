import { Transform } from "class-transformer";
import { IsString, IsNotEmpty, Matches } from "class-validator";
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