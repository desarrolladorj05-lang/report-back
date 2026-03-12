import { Module } from "@nestjs/common";
import { ConfigModule, ConfigService } from "@nestjs/config";
import { TypeOrmModule } from "@nestjs/typeorm";
import { ReportModule } from "./modules/report/report.module";
import databaseConfig from "./config/database.config";
import { envValidationSchema } from "./config/env.validation";
import { SaleReportModule } from "./modules/sales/sales-report.module";

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: process.env.NODE_ENV === "production" ? undefined : ".env",
      validationSchema: envValidationSchema,
      load: [databaseConfig],
    }),
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) =>
        configService.get("database"),
    }),
    ReportModule,
    SaleReportModule,
  ],
})
export class AppModule {}
