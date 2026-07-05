// src/registros/registros.controller.ts
import { 
  Controller, 
  Get, 
  Post, 
  Put,
  Body, 
  Param, 
  Delete, 
  Query,
  ParseIntPipe 
} from '@nestjs/common';
import { RegistrosService } from './registros.service';
import { CreateRegistroDto } from './dto/create-registro.dto';
import { UpdateRegistroDto, SyncRegistrosBatchDto } from './dto/update-registro.dto';
import { Registro } from './entities/registro.entity';

@Controller('hijos/:hijoId/registros')
export class RegistrosController {
  constructor(private readonly registrosService: RegistrosService) {}

  @Post()
  create(
    @Param('hijoId', ParseIntPipe) hijoId: number,
    @Body() createRegistroDto: CreateRegistroDto
  ): Promise<Registro> {
    return this.registrosService.create({
      ...createRegistroDto,
      hijoId
    });
  }

  @Post('sync')
  syncBatch(
    @Param('hijoId', ParseIntPipe) hijoId: number,
    @Body() syncRegistrosBatchDto: SyncRegistrosBatchDto
  ): Promise<Registro[]> {
    return this.registrosService.createBatch(hijoId, syncRegistrosBatchDto);
  }

  @Put(':id')
  update(
    @Param('hijoId', ParseIntPipe) hijoId: number,
    @Param('id', ParseIntPipe) id: number,
    @Body() updateRegistroDto: UpdateRegistroDto
  ): Promise<Registro> {
    return this.registrosService.update(id, updateRegistroDto);
  }

  @Get()
  findByHijo(
    @Param('hijoId', ParseIntPipe) hijoId: number,
    @Query('fechaInicio') fechaInicio?: string,
    @Query('fechaFin') fechaFin?: string
  ): Promise<Registro[]> {
    if (fechaInicio && fechaFin) {
      return this.registrosService.findByHijoAndDateRange(
        hijoId, 
        new Date(fechaInicio), 
        new Date(fechaFin)
      );
    }
    
    return this.registrosService.findByHijo(hijoId);
  }

  @Get(':id')
  findOne(
    @Param('hijoId', ParseIntPipe) hijoId: number,
    @Param('id', ParseIntPipe) id: number
  ): Promise<Registro> {
    return this.registrosService.findOne(id);
  }

  @Delete(':id')
  remove(
    @Param('hijoId', ParseIntPipe) hijoId: number,
    @Param('id', ParseIntPipe) id: number
  ): Promise<void> {
    return this.registrosService.remove(id);
  }
}
