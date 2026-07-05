import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { ZonaSegura } from './entities/zona-segura.entity';
import { CreateZonaSeguraDto } from './dto/create-zona-segura.dto';
import { UpdateZonaSeguraDto } from './dto/update-zona-segura.dto';
import { Hijo } from '../usuarios/entities/hijo.entity';

@Injectable()
export class ZonasSegurasService {
  constructor(
    @InjectRepository(ZonaSegura)
    private readonly zonaSeguraRepository: Repository<ZonaSegura>,
    @InjectRepository(Hijo)
    private readonly hijoRepository: Repository<Hijo>,
  ) {}

  async create(createDto: CreateZonaSeguraDto, tutor): Promise<ZonaSegura> {
    const hijos = await this.hijoRepository.findBy({ 
      id: In(createDto.hijosIds) 
    });
    if (hijos.length !== createDto.hijosIds.length) {
      throw new NotFoundException('Uno o más hijos no existen');
    }
    const zona = this.zonaSeguraRepository.create({
      ...createDto,
      hijos,
      tutor,
    });
    return this.zonaSeguraRepository.save(zona);
  }

  async findAllByTutor(tutorId: number): Promise<ZonaSegura[]> {
    return this.zonaSeguraRepository.find({ where: { tutor: { id: tutorId } }, relations: ['hijos'] });
  }

  async update(id: number, updateDto: UpdateZonaSeguraDto, tutor): Promise<ZonaSegura> {
    const zona = await this.zonaSeguraRepository.findOne({ where: { id, tutor: { id: tutor.id } }, relations: ['hijos'] });
    if (!zona) throw new NotFoundException('Zona segura no encontrada');
    if (updateDto.hijosIds) {
      const hijos = await this.hijoRepository.findBy({ 
        id: In(updateDto.hijosIds) 
      });
      if (hijos.length !== updateDto.hijosIds.length) {
        throw new NotFoundException('Uno o más hijos no existen');
      }
      zona.hijos = hijos;
    }
    Object.assign(zona, updateDto);
    return this.zonaSeguraRepository.save(zona);
  }

  async remove(id: number, tutor): Promise<void> {
    const zona = await this.zonaSeguraRepository.findOne({ where: { id, tutor: { id: tutor.id } } });
    if (!zona) throw new NotFoundException('Zona segura no encontrada');
    await this.zonaSeguraRepository.remove(zona);
  }

  async findOne(id: number, tutor): Promise<ZonaSegura> {
    const zona = await this.zonaSeguraRepository.findOne({ where: { id, tutor: { id: tutor.id } }, relations: ['hijos'] });
    if (!zona) throw new NotFoundException('Zona segura no encontrada');
    return zona;
  }

  /**
   * 🔥 NUEVO: Verificar si un hijo está dentro de sus zonas seguras
   * Usa PostGIS ST_Contains para verificación geoespacial
   */
  async checkGeofenceStatus(
    hijoId: number,
    latitud: number,
    longitud: number,
  ): Promise<ZonaSegura[]> {
    // Buscar todas las zonas donde el hijo está asignado Y está dentro del polígono
    const zonasActuales = await this.zonaSeguraRepository
      .createQueryBuilder('zona')
      .innerJoin('zona.hijos', 'hijo')
      .leftJoinAndSelect('zona.tutor', 'tutor')
      .where('hijo.id = :hijoId', { hijoId })
      .andWhere(
        `ST_Contains(
          zona.poligono, 
          ST_SetSRID(ST_MakePoint(:longitud, :latitud), 4326)
        )`,
        { latitud, longitud }
      )
      .getMany();

    return zonasActuales;
  }

  /**
   * Buscar zona por ID (necesario para notificaciones de salida)
   */
  async findById(id: number): Promise<ZonaSegura | null> {
    return this.zonaSeguraRepository.findOne({
      where: { id },
      relations: ['tutor'],
    });
  }
}
