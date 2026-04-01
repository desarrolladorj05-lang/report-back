import { NestFactory } from "@nestjs/core";
import { AppModule } from "./app.module";
import { ValidationPipe } from "@nestjs/common";
import { HttpExceptionFilter } from "./common/filters/http-exception.filter";
import * as cookieParser from 'cookie-parser';

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
  
  // 1. Configuración de CORS dinámica
  app.enableCors({
    origin: (origin, callback) => {

      if (!origin || 
          origin.startsWith("http://localhost") || 
          origin.startsWith("http://192.168") || 
          origin === "https://management-report.isi.com.pe") {
        callback(null, true);
      } else {
        callback(new Error("Not allowed by CORS"));
      }
    },
    methods: "GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS",
    credentials: true,
    allowedHeaders: "Content-Type, Accept, Authorization",
  });

  const port = process.env.PORT || process.env.API_PORT || 3000;

  await app.listen(port, '0.0.0.0'); 
  
  console.log(`API corriendo en red local: http://0.0.0.0:${port}/api`);
}
bootstrap();