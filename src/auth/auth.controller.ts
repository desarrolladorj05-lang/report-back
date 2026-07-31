import {
  Body,
  Controller,
  Get,
  Post,
  Req,
  Request,
  Res,
  UnauthorizedException,
  UseGuards,
} from "@nestjs/common";
import { Throttle } from "@nestjs/throttler";
import { Request as ExpressRequest, Response } from "express";
import { AuthService } from "./auth.service";
import { LoginDto } from "./dto/login.dto";
import { RegisterDto } from "./dto/register.dto";
import { JwtAuthGuard } from "./jwt.auth.guard";

@Controller("auth")
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Throttle({ default: { limit: 4, ttl: 1200000 } })
  @Post("login")
  async login(
    @Body() loginDto: LoginDto,
    @Req() request: ExpressRequest,
    @Res({ passthrough: true }) response: Response,
  ) {
    const user = await this.authService.validateUser(
      loginDto.username,
      loginDto.password,
      this.getClientOrigin(request),
    );
    if (!user) throw new UnauthorizedException("Credenciales invalidas.");

    const accessToken = this.authService.generateAccessToken(user);
    response.cookie("access_token", accessToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "lax",
      maxAge: 3600000,
      path: "/",
    });
    return {
      message: "Login exitoso",
      user: {
        username: user.username,
        alias: user.alias,
        tenantId: user.tenantId,
        modules: user.modules,
      },
    };
  }

  @Throttle({ default: { limit: 5, ttl: 3600000 } })
  @Post("register")
  register(@Body() registerDto: RegisterDto, @Req() request: ExpressRequest) {
    return this.authService.register(
      registerDto.username,
      registerDto.password,
      this.getClientOrigin(request),
    );
  }

  @Post("logout")
  logout(@Res({ passthrough: true }) response: Response) {
    response.clearCookie("access_token", { path: "/" });
    return { message: "Sesion cerrada" };
  }

  @UseGuards(JwtAuthGuard)
  @Get("profile")
  getProfile(@Request() request) {
    return request.user;
  }

  private getClientOrigin(request: ExpressRequest): string | undefined {
    return (
      request.get("origin") ??
      request.get("referer") ??
      request.get("x-client-origin") ??
      undefined
    );
  }
}
