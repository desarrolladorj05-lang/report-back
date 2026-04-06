import { NestFactory } from "@nestjs/core";
import { AppModule } from "./app.module";
import { ValidationPipe } from "@nestjs/common";
import { HttpExceptionFilter } from "./common/filters/http-exception.filter";
import * as cookieParser from "cookie-parser";

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.setGlobalPrefix("api");
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
    }),
  );
  app.useGlobalFilters(new HttpExceptionFilter());
  app.use(cookieParser());

  app.enableCors({
    origin: [
      "https://management-report.isi.com.pe",
      "http://localhost:5173",
      "http://localhost:3000",
      // Agrega esta si usas la IP de tu red local a veces
      /^http:\/\/192\.168\.1\.\d{1,3}:5173$/,
    ],
    methods: "GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS",
    credentials: true,
    allowedHeaders: "Content-Type, Accept, Authorization",
  });

  const port = process.env.PORT || process.env.API_PORT || 3000;

  // GUARDAMOS la instancia del servidor para configurar el tiempo de espera
  const server = await app.listen(port);

  // ESTA ES LA CLAVE: Aumenta el tiempo que el servidor espera antes de dar el 504
  // 300,000ms = 5 minutos. Esto ayuda si tus reportes de ventas son pesados.
  server.setTimeout(300000);

  console.log(`API corriendo en http://localhost:${port}/api`);
}
bootstrap();
