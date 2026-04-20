import { BadRequestException, Controller, Get, Logger, Param, Query, UseGuards } from "@nestjs/common";
import { CashPettyReportService } from "./cash-petty-report.service";
import { JwtAuthGuard } from "src/auth/jwt.auth.guard";
import { CashPettyDetailDto, CashPettyReportDto } from "./cash-petty-report.dto";

@Controller("cash-petty")
export class CashPettyReportController {
	private readonly logger = new Logger(CashPettyReportController.name);

	constructor(private readonly reportService: CashPettyReportService) {}

	@UseGuards(JwtAuthGuard)
	@Get("report")
	async getManagmentReportSales(@Query() query: CashPettyReportDto) {
		if (!query.year || !query.month) throw new BadRequestException("Periodo obligatorio");

		const start = Date.now();
		const result = await this.reportService.getCashPettyReport(query.year, query.month);

		this.logger.log(`[/report] Finalizado en ${Date.now() - start}ms`);
		return result;
	}

	@UseGuards(JwtAuthGuard)
	@Get("/:id/movements")
	async getCashPettyDetail(@Param() params: CashPettyDetailDto) {
		const start = Date.now();

		const result = await this.reportService.getCashPettyDetail(params.id);

		this.logger.log(
			`[/cash-petty/${params.id}/movements] ${Date.now() - start}ms`,
		);

		return result;
	}
}