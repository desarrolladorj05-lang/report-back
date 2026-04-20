import { Injectable } from "@nestjs/common";
import { TenantDataSourceFactory } from "src/config/tenancy/tenant-ds.factory";
import { CashPettyDetailProcedure, CashPettyDetailResult } from "src/database/procedures-documentation/cash-petty-detail";
import { CashPettyReportProcedure, CashPettyReportResult } from "src/database/procedures-documentation/cash-petty.report";
import { BaseRepository } from "src/database/repositories/base.repository";

@Injectable()
export class CashPettyReportRepository extends BaseRepository<any> {
	getRepository() {
		throw new Error("Method not implement.");
	}
	
	constructor(dsFactory: TenantDataSourceFactory) {
		super(Object as any, dsFactory);
	}

	async getCashPettyReport(year: number, month: number): Promise<CashPettyReportResult> {
		const result = await this.executeProcedure({
			name: CashPettyReportProcedure.CASH_PETTY_REPORT.name,
			params: {
				p_year: year,
				p_month: month,
			},
		});

		const firstRow = result[0];
		const reportData = firstRow ? Object.values(firstRow)[0] : null;

		return reportData as CashPettyReportResult;
	}

	async getCashPettyDetail(id: string): Promise<CashPettyDetailResult> {
		const result = await this.executeProcedure({
			name: CashPettyDetailProcedure.CASH_PETTY_DETAIL.name,
			params: {
				p_cash_petty_id: id,
			},
		});

		const firstRow = result[0];
		const data = firstRow ? Object.values(firstRow)[0] : null;

		return data as CashPettyDetailResult;
	}
}