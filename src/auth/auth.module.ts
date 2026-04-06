import { Module } from "@nestjs/common";
import { JwtModule } from "@nestjs/jwt";
import { PassportModule } from "@nestjs/passport";
import { TypeOrmModule } from "@nestjs/typeorm";
import { ConfigModule, ConfigType } from "@nestjs/config";
import { AuthService } from "./auth.service";
import { AuthController } from "./auth.controller";
import { appConfig } from "../config/app.config";
import { JwtStrategy } from "./jwt.strategy";
import { user_auth } from "src/users/user.entity";
import { SSemModule } from "src/users/module.entity";
import { SSemUserModule } from "src/users/user_module.entity";
@Module({
  imports: [
    PassportModule,
    TypeOrmModule.forFeature([user_auth, SSemModule, SSemUserModule]),
    ConfigModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [appConfig.KEY],
      useFactory: (config: ConfigType<typeof appConfig>) => ({
        secret: config.auth.JWT_SECRET,
        signOptions: { expiresIn: config.auth.JWT_EXPIRATION as any },
      }),
    }),
  ],
  providers: [AuthService, JwtStrategy],
  controllers: [AuthController],
  exports: [AuthService],
})
export class AuthModule {}
