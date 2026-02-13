import { Entity, ViewColumn, ViewEntity } from 'typeorm';

@ViewEntity({
    name: 'vw_mat_reporte_ventas',
})
export class SalesView {
    @ViewColumn()
    id_unico: string;

    @ViewColumn()
    idlocal: number;

    @ViewColumn()
    codelocal: string;

    @ViewColumn()
    dslocal: string;

    @ViewColumn()
    aniomes: string;

    @ViewColumn()
    dsaniomes: string;

    @ViewColumn()
    fecha: Date;

    @ViewColumn()
    dsturno: string;

    @ViewColumn()
    codproducto: number;

    @ViewColumn()
    dsproducto: string;

    @ViewColumn()
    monto: number;

    @ViewColumn()
    cantidad: number;
}
