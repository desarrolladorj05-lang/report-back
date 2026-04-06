import {
  Controller,
  Post,
  Body,
  UseGuards,
  Get,
  Request,
  Res,
  UnauthorizedException,
} from "@nestjs/common";
import { Throttle } from "@nestjs/throttler";
import { Response } from "express"; // Importación esencial
import { AuthService } from "./auth.service";
import { JwtAuthGuard } from "./jwt.auth.guard";
import { LoginDto } from "./dto/login.dto";4
import { RegisterDto } from "./dto/register.dto";

@Controller("auth")
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  // MANTENEMOS TUS INTENTOS: 4 intentos cada 20 minutos
  @Throttle({ default: { limit: 4100, ttl: 1200000 } })
  @Post("login")
  async login(
    @Body() loginDto: LoginDto,
    @Res({ passthrough: true }) response: Response, // Agregamos el objeto Response
  ) {
    const user = await this.authService.validateUser(
      loginDto.username,
      loginDto.password,
    );

    if (!user) {
      // Usamos UnauthorizedException para que Nest maneje el error correctamente
      throw new UnauthorizedException("Credenciales inválidas.");
    }

    const accessToken = this.authService.generateAccessToken(user);

    // CONFIGURAMOS LA COOKIE
    response.cookie("access_token", accessToken, {
      httpOnly: true, // Protege contra XSS (el front no puede leer el token)
      secure: false, // Cambiar a true solo en producción (HTTPS)
      sameSite: "lax", // Protección básica contra CSRF
      maxAge: 3600000, // 1 hora de vida (en milisegundos)
      path: "/", // Disponible en toda la aplicación
    });

    // Retornamos algo sencillo, el navegador ya guardó la cookie
    return {
      message: "Login exitoso",
      user: { username: user.username },
    };
  }

  // MANTENEMOS TUS INTENTOS: 5 registros por hora
  @Throttle({ default: { limit: 5, ttl: 3600000 } })
  @Post("register")
  async register(@Body() registerDto: RegisterDto) {
    return this.authService.register(
      registerDto.username,
      registerDto.password,
    );
  }

  @Post("logout")
  async logout(@Res({ passthrough: true }) response: Response) {
    // Borramos la cookie para cerrar sesión
    response.clearCookie("access_token");
    return { message: "Sesión cerrada" };
  }

  @UseGuards(JwtAuthGuard)
  @Get("profile")
  getProfile(@Request() req) {
    // Gracias al PassportStrategy actualizado, aquí tendrás el usuario
    return req.user;
  }
}
