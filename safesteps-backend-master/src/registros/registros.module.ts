// src/registros/registros.module.ts
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { RegistrosService } from './registros.service';
import { RegistrosController } from './registros.controller';
import { Registro } from './entities/registro.entity';
import { Hijo } from '../usuarios/entities/hijo.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Registro, Hijo])],
  controllers: [RegistrosController],
  providers: [RegistrosService],
})
export class RegistrosModule {}