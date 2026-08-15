import {
  Column,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from "typeorm";
import { Tenant } from "./tenant.entity";

@Entity("tenant_url")
export class TenantUrl {
  @PrimaryGeneratedColumn("uuid", { name: "id" })
  id: string;

  @Column({ name: "domain" })
  domain: string;

  @Column({ name: "subdomain", default: "" })
  subdomain: string;

  @ManyToOne(() => Tenant, { eager: true, nullable: false })
  @JoinColumn({ name: "tenant_id" })
  tenant: Tenant;
}
