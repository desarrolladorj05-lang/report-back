import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from "@nestjs/common";
import { Reflector } from "@nestjs/core";
import { AuthenticatedRequest } from "./authz.types";
import { AuthzService } from "./authz.service";
import { REQUIRED_MENU_KEY } from "./require-menu.decorator";

@Injectable()
export class MenuAccessGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly authzService: AuthzService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const requiredPath = this.reflector.getAllAndOverride<string>(
      REQUIRED_MENU_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!requiredPath) return true;

    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const bootstrap = await this.authzService.getBootstrap(request.user.userId);
    const paths = this.flattenPaths(bootstrap.menus);
    if (paths.has(this.normalize(requiredPath))) return true;
    throw new ForbiddenException("No tienes acceso a este reporte");
  }

  private flattenPaths(menus: Array<{ path: string | null; children: any[] }>) {
    const paths = new Set<string>();
    const visit = (items: Array<{ path: string | null; children: any[] }>) => {
      items.forEach((item) => {
        if (item.path) paths.add(this.normalize(item.path));
        visit(item.children ?? []);
      });
    };
    visit(menus);
    return paths;
  }

  private normalize(path: string) {
    const normalized = `/${path}`.replace(/\/+/g, "/");
    return normalized.length > 1 ? normalized.replace(/\/$/, "") : normalized;
  }
}
