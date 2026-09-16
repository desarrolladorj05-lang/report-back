import { createHash } from "crypto";
import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";
import { TenantDataSourceFactory } from "src/config/tenancy/tenant-ds.factory";
import { AuthLocal, AuthMenu, AuthzContext } from "./authz.types";

const ACTIVE_STATE = 1200001;
const MODULE_CODES = ["report", "MANAGEMENT_REPORT", "M2"];

interface PermissionRow {
  permission_codes: string[] | null;
  local_ids: string[] | null;
  has_all_locals: boolean;
}

interface MenuRow {
  menu_id: number;
  menu_code: string;
  menu_key: string;
  menu_name: string;
  parent_id: number | null;
  level: number;
  order_index: number;
  path_key: string | null;
  is_active: boolean;
  accesses: Array<{ accessId: number; accessCode: string }> | null;
}

@Injectable()
export class AuthzService {
  constructor(private readonly dataSourceFactory: TenantDataSourceFactory) {}

  async getContext(userId: string): Promise<AuthzContext> {
    const dataSource = await this.dataSourceFactory.get();
    const [permissionRows, locals] = await Promise.all([
      dataSource.query(
        "SELECT * FROM public.sp_user_permission_codes_by_user($1, $2)",
        [userId, ACTIVE_STATE],
      ) as Promise<PermissionRow[]>,
      this.getLocals(userId),
    ]);
    const row = permissionRows[0];

    const context = {
      permissionCodes: this.strings(row?.permission_codes),
      locals,
      hasAllLocals: Boolean(row?.has_all_locals),
    };
    return context;
  }

  async getBootstrap(userId: string) {
    const dataSource = await this.dataSourceFactory.get();
    const [userRows, context, menuRows] = await Promise.all([
      dataSource.query(
        `SELECT id_user, username, alias
         FROM public.user_auth
         WHERE id_user = $1 AND is_active = true
         LIMIT 1`,
        [userId],
      ),
      this.getContext(userId),
      dataSource.query(
        `WITH report_module AS (
           SELECT id_module
           FROM public.s_sem_module
           WHERE module_code = ANY($3::varchar[])
             AND is_active = true
             AND state_audit = $2
         ),
         allowed AS (
           SELECT
             permitted.menu_id,
             permitted.menu_code,
             permitted.menu_key,
             permitted.menu_name,
             permitted.parent_id,
             permitted.level,
             permitted.order_index,
             permitted.path_key,
             menu.is_active,
             permitted.accesses
           FROM public.sp_user_allowed_menus_by_user($1, $2) AS permitted
           INNER JOIN public.s_sem_menu AS menu
             ON menu.id_menu = permitted.menu_id
           INNER JOIN report_module AS module
             ON module.id_module = menu.module_id
         ),
         disabled AS (
           SELECT
             menu.id_menu AS menu_id,
             menu.menu_code,
             menu.menu_key,
             menu.menu_name,
             menu.parent_id,
             menu.level,
             menu.order_index,
             menu.path_key,
             menu.is_active,
             '[]'::jsonb AS accesses
           FROM public.s_sem_menu AS menu
           INNER JOIN report_module AS module
             ON module.id_module = menu.module_id
           WHERE menu.state_audit = $2
             AND menu.is_active = false
         )
         SELECT * FROM allowed
         UNION ALL
         SELECT * FROM disabled
         ORDER BY order_index, menu_name`,
        [userId, ACTIVE_STATE, MODULE_CODES],
      ) as Promise<MenuRow[]>,
    ]);

    const user = userRows[0];
    if (!user) throw new UnauthorizedException("Usuario no autorizado");

    const menus = this.toTree(menuRows);
    const authzVersion = createHash("sha256")
      .update(JSON.stringify({ menus, ...context }))
      .digest("hex");

    const bootstrap = {
      authzVersion,
      user: {
        userId: user.id_user,
        username: user.username,
        alias: user.alias,
      },
      menus,
      ...context,
    };
    return bootstrap;
  }

  async resolveLocalNumber(userId: string, localNumber?: number) {
    const context = await this.getContext(userId);
    if (context.hasAllLocals) return { context, localNumber };
    if (localNumber === undefined) {
      if (context.locals.length === 1) {
        return { context, localNumber: context.locals[0].number };
      }
      throw new BadRequestException(
        "Debes seleccionar una de las sedes que tienes asignadas",
      );
    }
    if (!context.locals.some((local) => local.number === localNumber)) {
      throw new ForbiddenException("No tienes acceso a la sede solicitada");
    }
    return { context, localNumber };
  }

  private async getLocals(userId: string): Promise<AuthLocal[]> {
    const dataSource = await this.dataSourceFactory.get();
    const rows = await dataSource.query(
      `SELECT l.id_local, l.local_number, l.local_name, l.name, l.local_code
       FROM public.user_local AS ul
       INNER JOIN public.local AS l ON l.id_local = ul.local_id
       WHERE ul.user_auth_id = $1
         AND ul.is_active = true
         AND ul.state_audit = $2
         AND l.is_active = true
         AND l.state_audit = $2
       ORDER BY l.local_number, COALESCE(l.local_name, l.name)`,
      [userId, ACTIVE_STATE],
    );

    return rows.map((row: any) => ({
      id: row.id_local,
      number: Number(row.local_number),
      name: row.local_name ?? row.name ?? `Sede ${row.local_number}`,
      code: row.local_code ?? null,
    }));
  }

  private toTree(rows: MenuRow[]): AuthMenu[] {
    const nodes = new Map<number, AuthMenu>();
    rows.forEach((row) =>
      nodes.set(row.menu_id, {
        id: row.menu_id,
        code: row.menu_code,
        key: row.menu_key,
        name: row.menu_name,
        parentId: row.parent_id,
        level: row.level,
        orderIndex: row.order_index,
        path: row.path_key,
        isActive: Boolean(row.is_active),
        accesses: row.accesses ?? [],
        children: [],
      }),
    );

    const roots: AuthMenu[] = [];
    nodes.forEach((menu) => {
      const parent = menu.parentId ? nodes.get(menu.parentId) : undefined;
      if (parent) parent.children.push(menu);
      else roots.push(menu);
    });
    const sort = (items: AuthMenu[]) => {
      items.sort((a, b) => a.orderIndex - b.orderIndex || a.name.localeCompare(b.name));
      items.forEach((item) => sort(item.children));
    };
    sort(roots);
    return roots;
  }

  private strings(values: string[] | null | undefined): string[] {
    return [...new Set((values ?? []).filter(Boolean))].sort();
  }
}
