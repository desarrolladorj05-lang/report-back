import { registerAs } from "@nestjs/config";
export const appConfig = registerAs("app", () => ({
  auth: {
    JWT_SECRET: process.env.JWT_SECRET || "default_secret",
    JWT_EXPIRATION: process.env.JWT_EXPIRATION || "1h",
  },
}));
