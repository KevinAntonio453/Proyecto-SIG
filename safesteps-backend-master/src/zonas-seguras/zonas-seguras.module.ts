import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ZonasSegurasController } from './zonas-seguras.controller';
import { ZonasSegurasService } from './zonas-seguras.service';
import { ZonaSegura } from './entities/zona-segura.entity';
import { Hijo } from '../usuarios/entities/hijo.entity';

@Module({
  imports: [TypeOrmModule.forFeature([ZonaSegura, Hijo])],
  controllers: [ZonasSegurasController],
  providers: [ZonasSegurasService],
  exports: [ZonasSegurasService],
})
export class ZonasSegurasModule {}
