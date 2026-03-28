import { NestFactory } from "@nestjs/core";
import { AppModule } from "./app.module";
import { ValidationPipe } from "@nestjs/common";
import { HttpExceptionFilter } from "./common/filters/http-exception.filter";
import * as cookieParser from 'cookie-parser';
async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.setGlobalPrefix("api"); // ej: /api/report/ventas
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
    }),
  );
  app.useGlobalFilters(new HttpExceptionFilter());

  app.use(cookieParser());
  
  // Enable CORS for frontend (Netlify + local dev)
  app.enableCors({
    origin: [
      "https://management-report.isi.com.pe", // Producción cloudFlare
      "http://localhost:5173", // Vite dev
      "http://localhost:3000", // Local testing
    ],
    methods: "GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS",
    credentials: true,
    allowedHeaders: "Content-Type, Accept, Authorization",
  });

  const port = process.env.PORT || process.env.API_PORT || 3000;
  await app.listen(port);
  console.log(`API corriendo en http://localhost:${port}/api`);
}
bootstrap();
