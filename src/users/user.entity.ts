import { Entity, Column, PrimaryGeneratedColumn } from "typeorm";
import {
  UpdateColumCustom,
  CreateColumCustom,
} from "src/common/typeORM/auditColumns";

@Entity("user_auth")
export class user_auth {
  @PrimaryGeneratedColumn("uuid", { name: "id_user" })
	id: string;

  @Column({ name: "username" })
  username: string;

  @Column({ name: "password" })
  password: string;

  @Column({ name: "card_number" })
  card_number: string;

  @Column({ name: "alias" })
  alias: string;

  @Column({ name: "id_person" })
  id_person: string;

  @Column({ name: "tenant_id" })
  tenant_id: string;

  @Column({ name: "is_active" })
  is_active: boolean;

  @Column({ name: "migration_sync_id" })
  migration_sync_id: string;

  @Column({ name: "meta_data", type: "json" })
  meta_data: any;

  @Column({ name: "updated_sync_at" })
  updated_sync_at: Date;

  @Column({ name: "created_by" })
  created_by: string;

  @Column({ name: "updated_by" })
  updated_by: string;

  @CreateColumCustom()
  created_at: Date;

  @UpdateColumCustom()
  updated_at: Date;

  @Column({ name: "state_audit" })
  state_audit: string;
}
