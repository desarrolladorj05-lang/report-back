import { Injectable } from "@nestjs/common";
import { DataSource } from "typeorm";
import { ConfigService } from "@nestjs/config";

@Injectable()
export class TenantDataSourceFactory {
  private dataSource: DataSource;

  constructor(private configService: ConfigService) {}

  async get(): Promise<DataSource> {
    if (!this.dataSource || !this.dataSource.isInitialized) {
      this.dataSource = await this.createDataSource();
    }
    return this.dataSource;
  }

  private async createDataSource(): Promise<DataSource> {
    const dataSource = new DataSource({
      type: "postgres",
      host: this.configService.get("DB_HOST"),
      port: this.configService.get("DB_PORT"),
      username: this.configService.get("DB_USER"),
      password: this.configService.get("DB_PASSWORD"),
      database: this.configService.get("DB_NAME"),
      ssl:
        this.configService.get("DB_SSL") === "true"
          ? { rejectUnauthorized: false }
          : false,
      entities: [__dirname + "/../../**/*.entity{.ts,.js}"],
      synchronize: false,
      logging: this.configService.get("NODE_ENV") === "development",
    });

    return dataSource.initialize();
  }
}
