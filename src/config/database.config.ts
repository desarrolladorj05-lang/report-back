import { registerAs } from "@nestjs/config";

export default registerAs("database", () => ({
  type: "postgres",
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT || "1506", 10),
  username: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  ssl: process.env.DB_SSL === "true" ? { rejectUnauthorized: false } : false,
  autoLoadEntities: true,
  synchronize: false, 
  logging: process.env.NODE_ENV === "development",
}));
