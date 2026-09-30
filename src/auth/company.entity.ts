import { Column, Entity, PrimaryGeneratedColumn } from "typeorm";

@Entity("company")
export class Company {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column()
  name: string;

  @Column()
  status: number;

  @Column({ name: "state_audit" })
  stateAudit: number;
}
