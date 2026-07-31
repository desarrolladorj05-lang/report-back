import { Injectable, UnauthorizedException } from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import * as bcrypt from "bcryptjs";
import { TenantDataSourceFactory } from "src/config/tenancy/tenant-ds.factory";
import { TenantResolverService } from "src/config/tenancy/tenant-resolver.service";
import { user_auth } from "src/users/user.entity";
import { SSemUserModule } from "src/users/user_module.entity";

@Injectable()
export class AuthService {
  constructor(
    private readonly tenantResolver: TenantResolverService,
    private readonly tenantDataSourceFactory: TenantDataSourceFactory,
    private readonly jwtService: JwtService,
  ) {}

  async validateUser(
    username: string,
    password: string,
    clientOrigin?: string,
  ): Promise<any> {
    const tenant = await this.tenantResolver.resolveForLogin(clientOrigin);
    const dataSource = await this.tenantDataSourceFactory.get();
    const userRepository = dataSource.getRepository(user_auth);
    const userModuleRepository = dataSource.getRepository(SSemUserModule);

    const user = await userRepository.findOne({
      where: { username: username.trim().toLowerCase(), is_active: true },
      select: [
        "id_user",
        "username",
        "password",
        "alias",
        "is_active",
        "tenant_id",
      ],
    });

    if (
      !user ||
      (user.tenant_id && user.tenant_id !== tenant.id) ||
      !(await bcrypt.compare(password, user.password))
    ) {
      return null;
    }

    const permissions = await userModuleRepository.find({
      where: { user_id: user.id_user, isActive: true },
      relations: ["module"],
    });
    const hasAccess = permissions.some(
      (permission) =>
        Number(permission.moduleId) === 2 ||
        permission.module?.code === "MANAGEMENT_REPORT",
    );
    if (!hasAccess) {
      throw new UnauthorizedException(
        "Acceso denegado. El usuario no cuenta con los permisos necesarios.",
      );
    }

    const { password: _password, ...result } = user;
    const modules = permissions.map((permission) => ({
      id: permission.module.id_module,
      code: permission.module.code,
      name: permission.module.name,
      route: permission.module.route,
    }));
    return { ...result, tenantId: tenant.id, modules };
  }

  async login(username: string, password: string, clientOrigin?: string) {
    const user = await this.validateUser(username, password, clientOrigin);
    if (!user) throw new UnauthorizedException("Credenciales invalidas.");
    return {
      accessToken: this.generateAccessToken(user),
      user: {
        id: user.id_user,
        username: user.username,
        alias: user.alias,
        tenantId: user.tenantId,
        modules: user.modules,
      },
    };
  }

  async register(username: string, password: string, clientOrigin?: string) {
    const tenant = await this.tenantResolver.resolveForLogin(clientOrigin);
    const dataSource = await this.tenantDataSourceFactory.get();
    const userRepository = dataSource.getRepository(user_auth);
    const hashedPassword = await bcrypt.hash(password, 10);
    const user = userRepository.create({
      username: username.trim().toLowerCase(),
      password: hashedPassword,
      tenant_id: tenant.id,
      is_active: true,
      state_audit: "40001",
    });
    return userRepository.save(user);
  }

  generateAccessToken(user: any): string {
    return this.jwtService.sign({
      username: user.username,
      sub: user.id_user,
      tenantId: user.tenantId,
      modules: user.modules || [],
    });
  }
}
