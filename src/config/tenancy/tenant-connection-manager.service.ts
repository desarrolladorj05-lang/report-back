import { join } from "path";
import { Injectable, OnModuleDestroy } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { LRUCache } from "lru-cache";
import { DataSource } from "typeorm";

@Injectable()
export class TenantConnectionManager implements OnModuleDestroy {
  private readonly cache: LRUCache<string, DataSource>;
  private readonly inFlight = new Map<string, Promise<DataSource>>();

  constructor(private readonly config: ConfigService) {
    this.cache = new LRUCache<string, DataSource>({
      max: this.config.get<number>("TENANT_CACHE_MAX", 100),
      ttl: this.config.get<number>("TENANT_POOL_TTL_MIN", 5) * 60_000,
      ttlAutopurge: true,
      updateAgeOnGet: true,
      dispose: (source) => {
        if (source.isInitialized) void source.destroy();
      },
    });
  }

  async get(dbName: string): Promise<DataSource> {
    const cached = this.cache.get(dbName);
    if (cached?.isInitialized) return cached;
    if (cached) this.cache.delete(dbName);

    const pending = this.inFlight.get(dbName);
    if (pending) return pending;

    const opening = this.create(dbName)
      .then((source) => {
        this.cache.set(dbName, source);
        return source;
      })
      .finally(() => this.inFlight.delete(dbName));

    this.inFlight.set(dbName, opening);
    return opening;
  }

  private create(database: string): Promise<DataSource> {
    const source = new DataSource({
      type: "postgres",
      host: this.config.get<string>("DB_HOST"),
      port: this.config.get<number>("DB_PORT", 1506),
      username: this.config.get<string>("DB_USER"),
      password: this.config.get<string>("DB_PASSWORD"),
      database,
      ssl:
        this.config.get<string>("DB_SSL") === "true"
          ? { rejectUnauthorized: false }
          : false,
      entities: [join(__dirname, "../../**/*.entity{.ts,.js}")],
      synchronize: false,
      logging: this.config.get<string>("NODE_ENV") === "development",
      extra: {
        max: this.config.get<number>("TENANT_POOL_SIZE", 15),
        connectionTimeoutMillis: 2000,
        idleTimeoutMillis: 10000,
      },
    });
    return source.initialize();
  }

  async onModuleDestroy(): Promise<void> {
    await Promise.all(
      [...this.cache.values()]
        .filter((source) => source.isInitialized)
        .map((source) => source.destroy()),
    );
    this.cache.clear();
  }
}
