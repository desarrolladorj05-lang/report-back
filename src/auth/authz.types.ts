import { Request } from "express";

export interface AuthLocal {
  id: string;
  number: number;
  name: string;
  code: string | null;
}

export interface AuthMenu {
  id: number;
  code: string;
  key: string;
  name: string;
  parentId: number | null;
  level: number;
  orderIndex: number;
  path: string | null;
  isActive: boolean;
  accesses: Array<{ accessId: number; accessCode: string }>;
  children: AuthMenu[];
}

export interface AuthzContext {
  permissionCodes: string[];
  locals: AuthLocal[];
  hasAllLocals: boolean;
}

export interface AuthenticatedUser {
  userId: string;
  username: string;
  tenantId: string;
  tenantDbName: string;
  modules: Array<{ id: number; code: string; name: string; route: string }>;
}

export type AuthenticatedRequest = Request & {
  user: AuthenticatedUser;
  authz?: AuthzContext;
};
