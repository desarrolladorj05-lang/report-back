import { Inject, Injectable } from "@nestjs/common";
import { ConfigType } from "@nestjs/config";
import { PassportStrategy } from "@nestjs/passport";
import { Request } from "express";
import { ExtractJwt, Strategy } from "passport-jwt";
import { appConfig } from "../config/app.config";
import { TenantResolverService } from "../config/tenancy/tenant-resolver.service";

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    @Inject(appConfig.KEY)
    config: ConfigType<typeof appConfig>,
    private readonly tenantResolver: TenantResolverService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromExtractors([
        (request: Request) => request?.cookies?.["access_token"] ?? null,
        ExtractJwt.fromAuthHeaderAsBearerToken(),
      ]),
      ignoreExpiration: false,
      secretOrKey: config.auth.JWT_SECRET,
    });
  }

  async validate(payload: any) {
    if (!payload.tenantId) throw new Error("El token no contiene tenantId.");
    const tenant = await this.tenantResolver.resolveById(payload.tenantId);
    return {
      userId: payload.sub,
      username: payload.username,
      tenantId: payload.tenantId,
      tenantDbName: tenant.dbName,
      modules: payload.modules || [],
    };
  }
}
