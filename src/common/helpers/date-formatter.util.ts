export class DateFormatter {
  /**
   * Valida si una cadena es una fecha válida en formato DD/MM/YYYY
   * @param dateStr - Fecha en formato 'DD/MM/YYYY'
   */
  static isValidFormat(dateStr: string): boolean {
    if (!dateStr) return false;
    
    const regex = /^(0[1-9]|[12][0-9]|3[01])\/(0[1-9]|1[0-2])\/\d{4}$/;
    return regex.test(dateStr);
  }
  /**
   * Convierte una fecha de texto (DD/MM/YYYY) a objeto Date
   * @param dateStr - Fecha en formato 'DD/MM/YYYY'
   */
  static toDate(dateStr: string): Date {
    if (!this.isValidFormat(dateStr)) {
      throw new Error(`Fecha inválida: ${dateStr}. Se espera formato DD/MM/YYYY`);
    }
    const [day, month, year] = dateStr.split('/').map(Number);
    return new Date(year, month - 1, day); // month - 1 porque en JS los meses van 0-11
  }
  /**
   * Convierte una fecha de texto (DD/MM/YYYY) a formato YYYY-MM-DD (para base de datos)
   * @param dateStr - Fecha en formato 'DD/MM/YYYY'
   */
  static toDatabaseFormat(dateStr: string): string {
    const date = this.toDate(dateStr);
    return date.toISOString().split('T')[0]; // YYYY-MM-DD
  }
  /**
   * Convierte una fecha de texto (DD/MM/YYYY) a formato YYYY-MM-DD HH:MM:SS
   * @param dateStr - Fecha en formato 'DD/MM/YYYY'
   */
  static toDateTimeDatabase(dateStr: string): string {
    const date = this.toDate(dateStr);
    return date.toISOString(); // Formato ISO
  }
  /**
   * Resta días a una fecha (DD/MM/YYYY)
   * @param dateStr - Fecha en formato 'DD/MM/YYYY'
   * @param days - Número de días a restar
   */
  static subtractDays(dateStr: string, days: number): string {
    const date = this.toDate(dateStr);
    date.setDate(date.getDate() - days);
    
    // Formatear de vuelta a DD/MM/YYYY
    const day = String(date.getDate()).padStart(2, '0');
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const year = date.getFullYear();
    
    return `${day}/${month}/${year}`;
  }
  /**
   * Suma días a una fecha (DD/MM/YYYY)
   * @param dateStr - Fecha en formato 'DD/MM/YYYY'
   * @param days - Número de días a sumar
   */
  static addDays(dateStr: string, days: number): string {
    const date = this.toDate(dateStr);
    date.setDate(date.getDate() + days);
    
    const day = String(date.getDate()).padStart(2, '0');
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const year = date.getFullYear();
    
    return `${day}/${month}/${year}`;
  }
}