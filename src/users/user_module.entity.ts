import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  ManyToOne,
  JoinColumn,
} from "typeorm";
import { user_auth } from "src/users/user.entity";
import {
  CreateColumCustom,
  UpdateColumCustom,
} from "src/common/typeORM/auditColumns";
import { SSemModule } from "./module.entity";

@Entity("s_sem_user_module")
export class SSemUserModule {
  @PrimaryGeneratedColumn("uuid", { name: "id_module_user" })
  id_module_userid: string;

  @Column({ name: "user_id" })
  user_id: string;

  @Column({ name: "module_id" })
  moduleId: number;

  @Column({ name: "is_active", default: true })
  isActive: boolean;

  @Column({ name: "note", nullable: true })
  note: string;

  // --- RELACIONES ---

  @ManyToOne(() => user_auth)
  @JoinColumn({ name: "user_id" })
  user: user_auth;

  @ManyToOne(() => SSemModule)
  @JoinColumn({ name: "module_id" })
  module: SSemModule;

  // --- AUDITORÍA ---

  @Column({ name: "created_by" })
  createdBy: string;

  @CreateColumCustom()
  createdAt: Date;

  @UpdateColumCustom()
  updatedAt: Date;

  @Column({ name: "state_audit" })
  stateAudit: string;
}
