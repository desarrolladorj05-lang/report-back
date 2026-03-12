import { Controller, Get, Query } from "@nestjs/common";
import { ReportService } from "./report.service";
import { SalesFilterDto } from "./dto/sales-filter.dto";
import {
  SalesResponseDto,
  GroupedSalesResponseDto,
  FilterOptionsResponseDto,
} from "./dto/response.dto";

@Controller("report")
export class ReportController {
  constructor(private readonly reportService: ReportService) {}

  // Tabla detalle (como la que muestras debajo del gráfico)
  @Get("ventas")
  async getVentas(@Query() filters: SalesFilterDto): Promise<SalesResponseDto> {
    // Asegurar que las fechas siempre tengan valores por defecto
    const today = new Date().toISOString().split("T")[0];
    const normalizedFilters = {
      ...filters,
      fechaInicio: filters.fechaInicio ?? today,
      fechaFin: filters.fechaFin ?? today,
    };

    console.log("📊 [GET /ventas] Filtros recibidos:", normalizedFilters);

    const data = await this.reportService.getRawSales(normalizedFilters);
    return {
      count: data.length,
      data,
    };
  }

  // Datos agregados para gráficos (líneas, columnas, pie)
  @Get("ventas-agrupado")
  async getVentasAgrupado(
    @Query() filters: SalesFilterDto,
  ): Promise<GroupedSalesResponseDto> {
    // Asegurar que las fechas siempre tengan valores por defecto
    const today = new Date().toISOString().split("T")[0];
    const normalizedFilters = {
      ...filters,
      fechaInicio: filters.fechaInicio ?? today,
      fechaFin: filters.fechaFin ?? today,
    };

    console.log(
      "📈 [GET /ventas-agrupado] Filtros recibidos:",
      normalizedFilters,
    );

    return await this.reportService.getGroupedSales(normalizedFilters);
  }

  // Opciones de filtros dinámicos (turnos y productos únicos)
  @Get("filter-options")
  async getFilterOptions(
    @Query() filters: SalesFilterDto,
  ): Promise<FilterOptionsResponseDto> {
    const today = new Date().toISOString().split("T")[0];
    const local = filters.local ?? 4;
    const fechaInicio = filters.fechaInicio ?? today;
    const fechaFin = filters.fechaFin ?? today;

    console.log("🔍 [GET /filter-options] Filtros recibidos:", {
      local,
      fechaInicio,
      fechaFin,
    });

    return await this.reportService.getFilterOptions(
      local,
      fechaInicio,
      fechaFin,
    );
  }
}
