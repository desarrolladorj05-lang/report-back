import { registerAs } from "@nestjs/config";
export const appConfig = registerAs("app", () => ({
  database: {
    host: process.env.DATABASE_HOST,
    port: parseInt(process.env.DATABASE_PORT || "1506"),
    username: process.env.DATABASE_USERNAME,
    password: process.env.DATABASE_PASSWORD,
    database: process.env.DATABASE_NAME,
  },
  auth: {
    JWT_SECRET: process.env.JWT_SECRET || "default_secret",
    JWT_EXPIRATION: process.env.JWT_EXPIRATION || "1h",
  },
}));
