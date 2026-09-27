import { Module } from "@nestjs/common";
import { AuthModule } from "src/auth/auth.module";
import { CommercialSalesController } from "./commercial-sales.controller";
import { CommercialSalesRepository } from "./commercial-sales.repository";
import { CommercialSalesService } from "./commercial-sales.service";

@Module({
  imports: [AuthModule],
  controllers: [CommercialSalesController],
  providers: [CommercialSalesRepository, CommercialSalesService],
})
export class CommercialSalesModule {}
