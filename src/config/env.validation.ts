import * as Joi from "joi";

export const envValidationSchema = Joi.object({
  DB_HOST: Joi.string().required(),
  DB_PORT: Joi.number().default(5432),
  DB_USER: Joi.string().required(),
  DB_PASSWORD: Joi.string().required(),
  DB_NAME: Joi.string().required(),
  DB_SSL: Joi.string().default("false"),
  DEV_TENANT_ID: Joi.string().uuid().optional(),
  DEV_TENANT_DB: Joi.string().optional(),
  TENANT_DOMAIN: Joi.string().default("isi.com.pe"),
  TENANT_CACHE_MAX: Joi.number().integer().positive().default(100),
  TENANT_POOL_SIZE: Joi.number().integer().positive().default(15),
  TENANT_POOL_TTL_MIN: Joi.number().integer().positive().default(5),
  PORT: Joi.number().default(1506),
  NODE_ENV: Joi.string()
    .valid("development", "production", "test")
    .default("development"),
});
