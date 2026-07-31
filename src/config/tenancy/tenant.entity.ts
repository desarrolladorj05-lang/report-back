import { Column, Entity, PrimaryGeneratedColumn } from "typeorm";

@Entity("tenant")
export class Tenant {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column({ name: "dbName" })
  dbName: string;

  @Column({ nullable: true })
  domain: string | null;

  @Column({ nullable: true })
  subdomain: string | null;

  @Column({ name: "isActive", default: true })
  isActive: boolean;
}
