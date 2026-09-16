import { BadRequestException, Controller, ForbiddenException, Get, Logger, Param, Query, Req, UseGuards } from "@nestjs/common";
import { CashPettyReportService } from "./cash-petty-report.service";
import { JwtAuthGuard } from "src/auth/jwt.auth.guard";
import { CashPettyDetailDto, CashPettyReportDto } from "./cash-petty-report.dto";
import { MenuAccessGuard } from "src/auth/menu-access.guard";
import { RequireMenu } from "src/auth/require-menu.decorator";
import { AuthzService } from "src/auth/authz.service";
import { AuthenticatedRequest } from "src/auth/authz.types";

@Controller("cash-petty")
@UseGuards(JwtAuthGuard, MenuAccessGuard)
@RequireMenu("/caja")
export class CashPettyReportController {
	private readonly logger = new Logger(CashPettyReportController.name);

	constructor(
		private readonly reportService: CashPettyReportService,
		private readonly authzService: AuthzService,
	) {}

	@Get("report")
	async getManagmentReportSales(
		@Query() query: CashPettyReportDto,
		@Req() request: AuthenticatedRequest,
	) {
		if (!query.year || !query.month) throw new BadRequestException("Periodo obligatorio");

		const start = Date.now();
		const [result, context] = await Promise.all([
			this.reportService.getCashPettyReport(query.year, query.month),
			this.authzService.getContext(request.user.userId),
		]);
		if (!context.hasAllLocals) {
			const allowed = new Set(context.locals.map((local) => local.id));
			result.sedes = result.sedes.filter((sede) => allowed.has(sede.idlocal));
		}

		this.logger.log(`[/report] Finalizado en ${Date.now() - start}ms`);
		return result;
	}

	@Get("/:id/movements")
	async getCashPettyDetail(
		@Param() params: CashPettyDetailDto,
		@Req() request: AuthenticatedRequest,
	) {
		const start = Date.now();

		const result = await this.reportService.getCashPettyDetail(params.id);
		const context = await this.authzService.getContext(request.user.userId);
		if (
			!context.hasAllLocals &&
			!context.locals.some((local) => local.id === result.sede.idlocal)
		) {
			throw new ForbiddenException("No tienes acceso a la sede de esta caja");
		}

		this.logger.log(
			`[/cash-petty/${params.id}/movements] ${Date.now() - start}ms`,
		);

		return result;
	}
}
