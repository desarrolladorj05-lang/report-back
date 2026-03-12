import { Injectable, BadRequestException } from "@nestjs/common";
import { Intervalo, SalesFilterDto } from "./dto/sales-filter.dto";
import { ReportRepository } from "./report.repository";
import { SalesReportResult } from "../../database/procedures-documentation/procedure-registry";

interface SalesRow {
  fecha: string;
  turno: string;
  producto: string;
  monto: number;
  cantidad: number;
}

@Injectable()
export class ReportService {
  constructor(private reportRepository: ReportRepository) {}

  private validateDates(fechaInicio: string, fechaFin: string): void {
    const start = new Date(fechaInicio);
    const end = new Date(fechaFin);

    if (start > end) {
      throw new BadRequestException(
        "fechaInicio no puede ser mayor que fechaFin",
      );
    }
  }

  /**
   * Normaliza nombres de productos a claves cortas
   * Convierte variantes como "DIESEL BS 550", "DIESEL B5 S50" → "DIESEL"
   * Retorna null para productos de tienda (gaseosa, agua, etc.)
   */
  private normalizeProduct(productName: string): string | null {
    if (!productName) return null;

    const n = productName.trim().toUpperCase();

    if (n.includes("DIESEL")) return "DIESEL";
    if (n.includes("GASOHOL PREMIUM") || n.includes("G. PREMIUM"))
      return "PREMIUM";
    if (n.includes("GASOHOL REGULAR") || n.includes("G. REGULAR"))
      return "REGULAR";
    if (n.includes("GLP")) return "GLP";

    return null; // productos de tienda (gaseosa, agua, etc.)
  }

  /**
   * Llamada directa al stored procedure usando el repositorio
   */
  async getFromSP(
    local: number,
    desde: string,
    hasta: string,
  ): Promise<SalesRow[]> {
    // Usamos el método específico del repositorio que procesa el JSONB
    const result: SalesReportResult =
      await this.reportRepository.getDashboardVentas({
        local,
        desde,
        hasta,
      });

    // El SP devuelve un JSONB con estructura { summary: {...}, details: [...] }
    // Retornamos el array de detalles
    return result.details || [];
  }

  /**
   * Obtiene las opciones de filtros dinámicos desde la vista
   * (turnos y productos únicos para un local y rango de fechas)
   * BLINDADO: Siempre retorna arrays, nunca null/undefined
   * NOTA: Este método requeriría SPs adicionales o consultas directas a la vista
   */
  async getFilterOptions(local: number, fechaInicio: string, fechaFin: string) {
    try {
      this.validateDates(fechaInicio, fechaFin);

      // TODO: Implementar con nuevos SPs o consultas a la vista
      // Por ahora, devolvemos arrays vacíos
      console.log(
        "🔍 [getFilterOptions] Método temporal - implementar con SPs",
      );

      return {
        turnos: [],
        productos: [],
      };
    } catch (error) {
      console.error("❌ [getFilterOptions] Error:", error);
      if (error instanceof BadRequestException) {
        throw error;
      }
      return {
        turnos: [],
        productos: [],
      };
    }
  }

  /**
   * Detalle crudo para tabla (sin agrupar)
   * Ahora lee del SP y aplica filtros en memoria
   * Devuelve productos ya normalizados (DIESEL, PREMIUM, REGULAR, GLP)
   */
  async getRawSales(filters: SalesFilterDto): Promise<SalesRow[]> {
    const local = filters.local ?? 4; // Default: local 4

    // CRÍTICO: Asegurar que las fechas nunca sean undefined/null
    const today = new Date().toISOString().split("T")[0];
    const fechaInicio = filters.fechaInicio ?? today;
    const fechaFin = filters.fechaFin ?? today;

    this.validateDates(fechaInicio, fechaFin);

    console.log("🔧 [ReportService.getRawSales] Llamando SP con:", {
      local,
      fechaInicio,
      fechaFin,
    });

    const rows = await this.getFromSP(local, fechaInicio, fechaFin);

    return rows
      .filter((r) => {
        // Filtro por turno
        if (filters.turno && r.turno !== filters.turno) return false;

        // Filtro por productos (claves cortas)
        if (filters.productos) {
          const list = filters.productos.split(",").map((p) => p.trim());
          const prod = this.normalizeProduct(r.producto);
          if (!list.includes(prod)) return false;
        }

        return true;
      })
      .map((r) => ({
        ...r,
        producto: this.normalizeProduct(r.producto), // 👈 Normalizar antes de devolver
      }))
      .filter((r) => r.producto !== null); // Filtrar productos de tienda
  }

  /**
   * Datos agregados para gráficos (diario / mensual)
   * Ahora lee del SP y agrupa en memoria
   */
  async getGroupedSales(filters: SalesFilterDto) {
    const rows = await this.getRawSales(filters); // getRawSales ya valida fechas
    const intervalo = filters.intervalo ?? Intervalo.DIARIO;

    const map: Record<
      string,
      { eje: string; producto: string; monto: number; cantidad: number }
    > = {};
    for (const r of rows) {
      // Determinar el eje según el intervalo
      const eje =
        intervalo === Intervalo.MENSUAL
          ? r.fecha.substring(0, 7) // YYYY-MM
          : r.fecha; // YYYY-MM-DD

      const key = `${eje}-${r.producto}`;

      if (!map[key]) {
        map[key] = {
          eje,
          producto: r.producto,
          monto: 0,
          cantidad: 0,
        };
      }

      map[key].monto += Number(r.monto);
      map[key].cantidad += Number(r.cantidad);
    }

    // Transformar a formato de series para gráficos
    const grouped = Object.values(map);
    const seriesMap: Record<
      string,
      {
        productName: string;
        points: { eje: string; monto: number; cantidad: number }[];
      }
    > = {};

    for (const item of grouped) {
      const producto = item.producto;
      if (!seriesMap[producto]) {
        seriesMap[producto] = {
          productName: producto,
          points: [],
        };
      }
      seriesMap[producto].points.push({
        eje: item.eje,
        monto: item.monto,
        cantidad: item.cantidad,
      });
    }

    return {
      intervalo,
      series: Object.values(seriesMap),
    };
  }
}
