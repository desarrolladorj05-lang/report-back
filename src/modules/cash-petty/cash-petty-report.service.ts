import { BadRequestException, Injectable, Logger } from "@nestjs/common";
import { CashPettyReportRepository } from "./cash-petty-report.repository";
import { CashPettyReportResult } from "src/database/procedures-documentation/cash-petty.report";
import { DateFormatter } from "src/common/helpers/date-formatter.util";
import { CashPettyDetailResult } from "src/database/procedures-documentation/cash-petty-detail";

@Injectable()
export class CashPettyReportService {
	private readonly logger = new Logger(CashPettyReportService.name);

	constructor(private reportRepository: CashPettyReportRepository) {}

	async getCashPettyReport(fechaInicio: string, fechaFin: string): Promise<CashPettyReportResult> {
		this.logger.debug(`getCashPettyReport llamado con rango: ${fechaInicio} - ${fechaFin}`);

		if (!DateFormatter.isValidFormat(fechaInicio)) {
			this.logger.warn(`Formato de fecha inválido recibido: ${fechaInicio}`);
			throw new BadRequestException("Formato inválido en fecha de inicio");
		}

		if (!DateFormatter.isValidFormat(fechaFin)) {
			this.logger.warn(`Formato de fecha inválido recibido: ${fechaFin}`);
			throw new BadRequestException("Formato inválido en fecha de fin");
		}

		const result = await this.reportRepository.getCashPettyReport(
			fechaInicio,
			fechaFin,
		);

		if (!result) {
			this.logger.warn("SP devolvió null en cash petty report");

			return {
				fecha_inicio: fechaInicio,
				fecha_fin: fechaFin,
				sedes: [],
			};
		}

		return result;
	}

	async getCashPettyDetail(id: string): Promise<CashPettyDetailResult> {
		this.logger.debug(`getCashPettyDetail llamado con id: ${id}`);

		if (!id) {
			throw new BadRequestException("El ID es obligatorio");
		}

		const result = await this.reportRepository.getCashPettyDetail(id);

		if (!result) {
			this.logger.warn(`Caja no encontrada: ${id}`);
			throw new BadRequestException("No se encontró la caja chica especificada");
		}

		this.logger.debug(`Caja encontrada: ${id}`);
		
		return result;
	}
}