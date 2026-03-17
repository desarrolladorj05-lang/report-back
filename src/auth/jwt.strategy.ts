import { Inject, Injectable } from "@nestjs/common";
import { PassportStrategy } from "@nestjs/passport";
import { ExtractJwt, Strategy } from "passport-jwt";
import { ConfigType } from "@nestjs/config";
import { appConfig } from "../config/app.config";
import { Request } from 'express';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    @Inject(appConfig.KEY)
    private readonly config: ConfigType<typeof appConfig>,
  ) {
    super({
      // MODIFICACIÓN: Extraer el token de la cookie
      jwtFromRequest: ExtractJwt.fromExtractors([
        (request: Request) => {
          let token = null;
          if (request && request.cookies) {
            token = request.cookies['access_token'];
          }
          return token;
        },
        // Mantenemos esta por si acaso quieres probar con Postman usando Bearer Token
        ExtractJwt.fromAuthHeaderAsBearerToken(), 
      ]),
      ignoreExpiration: false,
      secretOrKey: config.auth.JWT_SECRET,
    });
  }

  async validate(payload: any) {
    // Esto es lo que se inyectará en req.user
    return { userId: payload.sub, username: payload.username };
  }
}