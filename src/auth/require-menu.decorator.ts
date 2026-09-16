import { SetMetadata } from "@nestjs/common";

export const REQUIRED_MENU_KEY = "required-menu-path";
export const RequireMenu = (path: string) =>
  SetMetadata(REQUIRED_MENU_KEY, path);
