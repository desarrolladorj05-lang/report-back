import { Entity, Column, PrimaryGeneratedColumn } from "typeorm";
import { CreateColumCustom, UpdateColumCustom } from "src/common/typeORM/auditColumns";

@Entity("s_sem_module")
export class SSemModule {
  @PrimaryGeneratedColumn("uuid", { name: "id_module" })
  id: string;

  @Column({ name: "module_code", unique: true })
  code: string;

  @Column({ name: "module_name" })
  name: string;

  @Column({ name: "description", nullable: true })
  description: string;

  @Column({ name: "route" })
  route: string;

  @Column({ name: "order_index", type: "int", default: 0 })
  orderIndex: number;

  @Column({ name: "is_active", default: true })
  isActive: boolean;

  @Column({ name: "metadata", type: "json", nullable: true })
  metadata: any;

  @Column({ name: "company_id", nullable: true })
  companyId: string;

  // Auditoría básica (reutilizando tus decoradores)
  @Column({ name: "created_by" })
  createdBy: string;

  @Column({ name: "updated_by" })
  updatedBy: string;

  @CreateColumCustom()
  createdAt: Date;

  @UpdateColumCustom()
  updatedAt: Date;

  @Column({ name: "state_audit" })
  stateAudit: string;
}