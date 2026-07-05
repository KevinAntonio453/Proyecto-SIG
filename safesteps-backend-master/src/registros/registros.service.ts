// src/registros/registros.service.ts
import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Registro } from './entities/registro.entity';
import { Hijo } from '../usuarios/entities/hijo.entity';
import { CreateRegistroDto } from './dto/create-registro.dto';
import { UpdateRegistroDto, SyncRegistrosBatchDto } from './dto/update-registro.dto';

@Injectable()
export class RegistrosService {
  constructor(
    @InjectRepository(Registro)
    private registrosRepository: Repository<Registro>,
    @InjectRepository(Hijo)
    private hijosRepository: Repository<Hijo>,
  ) {}

  async create(createRegistroDto: CreateRegistroDto): Promise<Registro> {
    const hijo = await this.hijosRepository.findOne({
      where: { id: createRegistroDto.hijoId }
    });

    if (!hijo) {
      throw new NotFoundException(`Hijo con ID ${createRegistroDto.hijoId} no encontrado`);
    }

    const registro = this.registrosRepository.create({
      hora: createRegistroDto.hora,
      latitud: createRegistroDto.latitud,
      longitud: createRegistroDto.longitud,
      hijoId: createRegistroDto.hijoId,
      fueOffline: createRegistroDto.fueOffline ?? false, // ← Usar valor del DTO
    });

    return await this.registrosRepository.save(registro);
  }

  async createBatch(hijoId: number, syncRegistrosBatchDto: SyncRegistrosBatchDto): Promise<Registro[]> {
    const hijo = await this.hijosRepository.findOne({
      where: { id: hijoId }
    });

    if (!hijo) {
      throw new NotFoundException(`Hijo con ID ${hijoId} no encontrado`);
    }

    const registros: Registro[] = [];

    for (const registroDto of syncRegistrosBatchDto.registros) {
      const registro = this.registrosRepository.create({
        hora: registroDto.hora,
        latitud: registroDto.latitud,
        longitud: registroDto.longitud,
        hijoId: hijoId,
        fueOffline: registroDto.fueOffline ?? false, // ← Usar valor del DTO
      });

      registros.push(registro);
    }

    return await this.registrosRepository.save(registros);
  }

  async update(id: number, updateRegistroDto: UpdateRegistroDto): Promise<Registro> {
    const registro = await this.findOne(id);
    
    if (updateRegistroDto.hora) registro.hora = updateRegistroDto.hora;
    if (updateRegistroDto.latitud) registro.latitud = updateRegistroDto.latitud;
    if (updateRegistroDto.longitud) registro.longitud = updateRegistroDto.longitud;
    if (updateRegistroDto.fueOffline !== undefined) registro.fueOffline = updateRegistroDto.fueOffline;

    return await this.registrosRepository.save(registro);
  }

  async findByHijo(hijoId: number): Promise<Registro[]> {
    const hijo = await this.hijosRepository.findOne({
      where: { id: hijoId }
    });

    if (!hijo) {
      throw new NotFoundException(`Hijo con ID ${hijoId} no encontrado`);
    }

    return await this.registrosRepository.find({
      where: { hijoId },
      order: { hora: 'DESC' }
    });
  }

  async findByHijoAndDateRange(
    hijoId: number, 
    fechaInicio: Date, 
    fechaFin: Date
  ): Promise<Registro[]> {
    const hijo = await this.hijosRepository.findOne({
      where: { id: hijoId }
    });

    if (!hijo) {
      throw new NotFoundException(`Hijo con ID ${hijoId} no encontrado`);
    }

    return await this.registrosRepository
      .createQueryBuilder('registro')
      .where('registro.hijoId = :hijoId', { hijoId })
      .andWhere('registro.hora BETWEEN :fechaInicio AND :fechaFin', {
        fechaInicio,
        fechaFin
      })
      .orderBy('registro.hora', 'DESC')
      .getMany();
  }

  async findOne(id: number): Promise<Registro> {
    const registro = await this.registrosRepository.findOne({
      where: { id },
      relations: ['hijo']
    });

    if (!registro) {
      throw new NotFoundException(`Registro con ID ${id} no encontrado`);
    }

    return registro;
  }

  async remove(id: number): Promise<void> {
    const registro = await this.findOne(id);
    await this.registrosRepository.remove(registro);
  }
}