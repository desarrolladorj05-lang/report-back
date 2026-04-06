import { Module } from "@nestjs/common";
import { ConfigModule, ConfigService } from "@nestjs/config";
import { TypeOrmModule } from "@nestjs/typeorm";
import { ThrottlerModule, ThrottlerGuard } from "@nestjs/throttler";
import { APP_GUARD } from "@nestjs/core";
import databaseConfig from "./config/database.config";
import { envValidationSchema } from "./config/env.validation";
import { SaleReportModule } from "./modules/sales/sales-report.module";
import { AuthModule } from "./auth/auth.module";
import { appConfig } from "./config/app.config";

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: process.env.NODE_ENV === "production" ? undefined : ".env",
      validationSchema: envValidationSchema,
      load: [databaseConfig, appConfig],
    }),
    ThrottlerModule.forRoot({
      throttlers: [
        {
          ttl: 60000, // 1 minute in milliseconds
          limit: 10, // 10 requests per minute per IP
        },
      ],
    }),
    // En tu AppModule.ts o donde tengas el factory de la base de datos
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        ...configService.get("database"),
        // CONFIGURACIÓN CRÍTICA PARA EVITAR EL ERROR 500 Y TLS
        extra: {
          // CONEXIONES 
          max: 20,         // Límite máximo de conexiones 
          min: 2,          // Mantiene 2 siempre abiertas (evita lag en la primera petición)
          
          // CIERRE DE INACTIVAS: Mata conexiones IDLE tras 10 segundos
          idleTimeoutMillis: 10000, 
          
          // VIDA MÁXIMA: Recicla conexiones cada hora (evita fugas de memoria)
          maxLifetimeMillis: 3600000, 
          
          // --- SEGURIDAD Y TIMEOUTS ---
          connectionTimeoutMillis: 2000, // Error rápido si la BD no responde en 2s
          statement_timeout: 60000,      // Cancela cualquier query que pase de 1 minuto
        },
        retryAttempts: 2,      // Menos reintentos para no bloquear el arranque
        retryDelay: 3000,
        keepConnectionAlive: true,
        autoLoadEntities: true,
      }),
    }),
    SaleReportModule,
    AuthModule,
  ],
  providers: [
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
  ],
})
export class AppModule { }
