import { Injectable, NotFoundException, ConflictException, BadRequestException, UnauthorizedException, Inject, forwardRef } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { Hijo } from './entities/hijo.entity';
import { CreateHijoDto } from './dto/create-hijo.dto';
import { UpdateHijoDto } from './dto/update-hijo.dto';
import { UpdateLocationDto } from './dto/update-location.dto';
import { User } from '../auth/entities/user.entity';
import { ZonasSegurasService } from '../zonas-seguras/zonas-seguras.service';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class HijoService {
  constructor(
    @InjectRepository(Hijo)
    private hijoRepository: Repository<Hijo>,
    @InjectRepository(User)
    private userRepository: Repository<User>,
    @Inject(forwardRef(() => ZonasSegurasService))
    private zonasService: ZonasSegurasService,
    @Inject(forwardRef(() => NotificationsService))
    private notificationsService: NotificationsService,
  ) {}

  async create(createHijoDto: CreateHijoDto): Promise<Hijo> {
    // Validar si el email ya existe
    const existingUser = await this.userRepository.findOne({
      where: { email: createHijoDto.email },
    });

    if (existingUser) {
      throw new ConflictException('El email ya está registrado');
    }

    const hashedPassword = await bcrypt.hash(createHijoDto.password, 10);
    const codigoVinculacion = this.generateVinculacionCode();

    const hijo = this.hijoRepository.create({
      nombre: createHijoDto.nombre,
      apellido: createHijoDto.apellido,
      email: createHijoDto.email,
      password: hashedPassword,
      telefono: createHijoDto.telefono,
      ultimaconexion: new Date(),
      codigoVinculacion,
      vinculado: false,
    });

    try {
      return await this.hijoRepository.save(hijo);
    } catch (error) {
      if (error.code === '23505') {
        throw new ConflictException('El email ya está registrado');
      }
      throw new BadRequestException('Error al crear el hijo');
    }
  }

  async findAll(): Promise<Hijo[]> {
    return this.hijoRepository.find({ relations: ['tutores'] });
  }

  async findOne(id: number): Promise<Hijo> {
    const hijo = await this.hijoRepository.findOne({
      where: { id },
      relations: ['tutores'],
    });

    if (!hijo) {
      throw new NotFoundException(`Hijo con ID ${id} no encontrado`);
    }

    return hijo;
  }

  async update(id: number, updateHijoDto: UpdateHijoDto): Promise<Hijo> {
    const hijo = await this.findOne(id);

    // Validar si se intenta cambiar el email
    if (updateHijoDto.email && updateHijoDto.email !== hijo.email) {
      // No permitir cambio de email si ya está vinculado
      if (hijo.vinculado) {
        throw new ConflictException('No se puede cambiar el email de un hijo ya vinculado');
      }

      // Validar si el nuevo email ya existe
      const existingUser = await this.userRepository.findOne({
        where: { email: updateHijoDto.email },
      });

      if (existingUser) {
        throw new ConflictException('El email ya está registrado');
      }
    }

    if (updateHijoDto.password) {
      updateHijoDto.password = await bcrypt.hash(updateHijoDto.password, 10);
    }

    Object.assign(hijo, updateHijoDto);
    
    try {
      return await this.hijoRepository.save(hijo);
    } catch (error) {
      if (error.code === '23505') {
        throw new ConflictException('El email ya está registrado');
      }
      throw new BadRequestException('Error al actualizar el hijo');
    }
  }

  async updateLocation(id: number, updateLocationDto: UpdateLocationDto): Promise<Hijo> {
    const hijo = await this.hijoRepository.findOne({
      where: { id },
      relations: ['tutores'],
    });

    if (!hijo) {
      throw new NotFoundException(`Hijo con ID ${id} no encontrado`);
    }

    // Validar coordenadas
    if (updateLocationDto.latitud < -90 || updateLocationDto.latitud > 90) {
      throw new BadRequestException('La latitud debe estar entre -90 y 90');
    }

    if (updateLocationDto.longitud < -180 || updateLocationDto.longitud > 180) {
      throw new BadRequestException('La longitud debe estar entre -180 y 180');
    }

    // 📍 Paso 1: Guardar estado anterior
    const estadoAnterior = hijo.estadoZona || 'FUERA';
    const zonaAnteriorId = hijo.zonaActualId;

    // 📍 Paso 2: Actualizar ubicación
    hijo.latitud = updateLocationDto.latitud;
    hijo.longitud = updateLocationDto.longitud;
    hijo.ultimaconexion = new Date();

    // 📍 Paso 3: Verificar zonas seguras con PostGIS (ST_Contains)
    let zonasActuales: any[] = [];
    try {
      zonasActuales = await this.zonasService.checkGeofenceStatus(
        id,
        updateLocationDto.latitud,
        updateLocationDto.longitud,
      );
    } catch (error) {
      console.error('❌ Error verificando zonas con PostGIS:', error);
    }

    // 📍 Paso 4: Determinar nuevo estado
    const estaDentro = zonasActuales.length > 0;
    const estadoNuevo = estaDentro ? 'DENTRO' : 'FUERA';
    const zonaNueva = estaDentro ? zonasActuales[0] : null;

    // 📍 Paso 5: Actualizar estado en BD
    hijo.estadoZona = estadoNuevo;
    hijo.zonaActualId = zonaNueva ? zonaNueva.id : null;

    try {
      await this.hijoRepository.save(hijo);
    } catch (error) {
      throw new BadRequestException('Error al actualizar la ubicación');
    }

    // 📍 Paso 6: Detectar cambios de estado y enviar notificaciones
    try {
      // 🟢 EVENTO: zone_entry (FUERA → DENTRO)
      if (estadoAnterior === 'FUERA' && estadoNuevo === 'DENTRO' && zonaNueva) {
        console.log(`🟢 ZONE_ENTRY: ${hijo.nombre} entró a ${zonaNueva.nombre}`);

        if (zonaNueva.tutor) {
          const mensaje = `🟢 ${hijo.nombre} ${hijo.apellido} entró a la zona segura "${zonaNueva.nombre}"`;
          
          // Guardar en BD
          await this.notificationsService.create(zonaNueva.tutor.id, {
            mensaje,
            tipo: 'zone_entry',
          });

          // 📱 Enviar Push FCM
          await this.notificationsService.sendPushNotification(
            zonaNueva.tutor.id,
            '🟢 Zona Segura',
            `${hijo.nombre} entró a ${zonaNueva.nombre}`,
            {
              type: 'zone_entry',
              childId: hijo.id,
              childName: `${hijo.nombre} ${hijo.apellido}`,
              zonaId: zonaNueva.id,
              zonaName: zonaNueva.nombre,
            },
          );
        }
      }

      // 🔴 EVENTO: zone_exit (DENTRO → FUERA)
      if (estadoAnterior === 'DENTRO' && estadoNuevo === 'FUERA' && zonaAnteriorId) {
        // Buscar info de la zona anterior
        const zonaAnterior = await this.zonasService.findById(zonaAnteriorId);
        
        if (zonaAnterior) {
          console.log(`🔴 ZONE_EXIT: ${hijo.nombre} salió de ${zonaAnterior.nombre}`);

          if (zonaAnterior.tutor) {
            const mensaje = `🔴 ${hijo.nombre} ${hijo.apellido} salió de la zona segura "${zonaAnterior.nombre}"`;
            
            // Guardar en BD
            await this.notificationsService.create(zonaAnterior.tutor.id, {
              mensaje,
              tipo: 'zone_exit',
            });

            // 📱 Enviar Push FCM
            await this.notificationsService.sendPushNotification(
              zonaAnterior.tutor.id,
              '🔴 Alerta de Zona',
              `${hijo.nombre} salió de ${zonaAnterior.nombre}`,
              {
                type: 'zone_exit',
                childId: hijo.id,
                childName: `${hijo.nombre} ${hijo.apellido}`,
                zonaId: zonaAnterior.id,
                zonaName: zonaAnterior.nombre,
              },
            );
          }
        }
      }

      // ℹ️ Log de estado (sin notificación)
      if (estadoAnterior === estadoNuevo) {
        if (estadoNuevo === 'DENTRO' && zonaNueva) {
          console.log(`ℹ️ ${hijo.nombre} continúa DENTRO de ${zonaNueva.nombre}`);
        } else {
          console.log(`ℹ️ ${hijo.nombre} continúa FUERA de zonas seguras`);
        }
      }
    } catch (error) {
      console.error('❌ Error procesando notificaciones de zona:', error);
    }

    return hijo;
  }

  async remove(id: number): Promise<void> {
    const hijo = await this.findOne(id);
    await this.hijoRepository.remove(hijo);
  }

  /**
   * Genera un código aleatorio de 6 caracteres alfanuméricos
   */
  private generateVinculacionCode(): string {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Sin caracteres ambiguos
    let code = '';
    for (let i = 0; i < 6; i++) {
      code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return code;
  }

  /**
   * Vincular dispositivo del hijo usando código
   */
  async vincularConCodigo(codigo: string, email: string, password: string): Promise<Hijo> {
    // Buscar hijo por código
    const hijo = await this.hijoRepository.findOne({
      where: { codigoVinculacion: codigo.toUpperCase() },
      relations: ['tutores'],
    });

    if (!hijo) {
      throw new NotFoundException('Código de vinculación inválido');
    }

    if (hijo.vinculado) {
      throw new ConflictException('Este código ya ha sido utilizado');
    }

    // Actualizar email y password del hijo
    hijo.email = email;
    hijo.password = await bcrypt.hash(password, 10);
    hijo.vinculado = true;

    try {
      return await this.hijoRepository.save(hijo);
    } catch (error) {
      if (error.code === '23505') {
        throw new ConflictException('El email ya está registrado');
      }
      throw new BadRequestException('Error al vincular dispositivo');
    }
  }

  /**
   * Obtener hijo por código de vinculación (info básica, sin datos sensibles)
   */
  async findByCodigo(codigo: string): Promise<{ nombre: string; apellido: string; vinculado: boolean }> {
    const hijo = await this.hijoRepository.findOne({
      where: { codigoVinculacion: codigo.toUpperCase() },
      select: ['nombre', 'apellido', 'vinculado'],
    });

    if (!hijo) {
      throw new NotFoundException('Código de vinculación inválido');
    }

    return {
      nombre: hijo.nombre,
      apellido: hijo.apellido,
      vinculado: hijo.vinculado,
    };
  }

  /**
   * Regenerar código de vinculación
   * Permite al tutor regenerar el código si el hijo pierde su dispositivo
   */
  async regenerarCodigo(id: number, tutorId: number): Promise<{ codigoVinculacion: string }> {
    const hijo = await this.findOne(id);

    // Verificar que el tutor sea el dueño del hijo
    const esTutorDelHijo = hijo.tutores.some(tutor => tutor.id === tutorId);
    if (!esTutorDelHijo) {
      throw new UnauthorizedException('No tienes permisos para regenerar el código de este hijo');
    }

    // Generar nuevo código y resetear vinculado
    hijo.codigoVinculacion = this.generateVinculacionCode();
    hijo.vinculado = false; // Permitir nueva vinculación

    await this.hijoRepository.save(hijo);

    return { codigoVinculacion: hijo.codigoVinculacion };
  }

  /**
   * Enviar alerta SOS de pánico a todos los tutores vinculados
   */
  async enviarAlertaSOS(hijoId: number, userId: number): Promise<{ message: string; notificacionesEnviadas: number }> {
    // Verificar que el usuario sea el hijo
    const hijo = await this.hijoRepository.findOne({
      where: { id: hijoId },
      relations: ['tutores'],
    });

    if (!hijo) {
      throw new NotFoundException(`Hijo con ID ${hijoId} no encontrado`);
    }

    if (hijo.id !== userId) {
      throw new UnauthorizedException('Solo el hijo puede enviar su propia alerta SOS');
    }

    if (!hijo.tutores || hijo.tutores.length === 0) {
      throw new BadRequestException('No tienes tutores vinculados para recibir la alerta');
    }

    // Preparar mensaje de alerta con ubicación actual
    const mensajeAlerta = hijo.latitud && hijo.longitud
      ? `🚨 ¡ALERTA SOS! ${hijo.nombre} ${hijo.apellido} necesita ayuda urgente.\n📍 Ubicación: ${hijo.latitud}, ${hijo.longitud}`
      : `🚨 ¡ALERTA SOS! ${hijo.nombre} ${hijo.apellido} necesita ayuda urgente.\n⚠️ Ubicación no disponible`;

    let notificacionesEnviadas = 0;

    // Enviar notificación a cada tutor
    for (const tutor of hijo.tutores) {
      try {
        // Crear notificación en base de datos
        await this.notificationsService.create(tutor.id, {
          mensaje: mensajeAlerta,
          tipo: 'sos_panico',
        });

        // Enviar notificación PUSH con type: 'sos_panico' en data
        await this.notificationsService.sendPushNotification(
          tutor.id,
          '🚨 ALERTA SOS',
          `${hijo.nombre} necesita ayuda urgente`,
          {
            type: 'sos_panico',  // IMPORTANTE: Este campo es el que detecta Flutter
            childId: hijo.id,
            childName: `${hijo.nombre} ${hijo.apellido}`,
            latitude: hijo.latitud?.toString() || '',
            longitude: hijo.longitud?.toString() || '',
          },
        );

        notificacionesEnviadas++;
      } catch (error) {
        console.error(`Error al enviar SOS al tutor ${tutor.id}:`, error);
      }
    }

    return {
      message: `Alerta SOS enviada a ${notificacionesEnviadas} tutor(es)`,
      notificacionesEnviadas,
    };
  }

  /**
   * Verifica si un tutor está vinculado a un hijo específico
   */
  async belongsToTutor(hijoId: number, tutorId: number): Promise<boolean> {
    const hijo = await this.hijoRepository.findOne({
      where: { id: hijoId },
      relations: ['tutores'],
    });
    if (!hijo) return false;
    return hijo.tutores.some(t => t.id === tutorId);
  }
}
