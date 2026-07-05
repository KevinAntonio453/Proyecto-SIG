import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { Notification } from './entities/notification.entity';
import { CreateNotificationDto } from './dto/create-notification.dto';
import { QueryNotificationsDto } from './dto/query-notifications.dto';
import { Tutor } from '../usuarios/entities/tutor.entity';
import * as admin from 'firebase-admin';

@Injectable()
export class NotificationsService {
  constructor(
    @InjectRepository(Notification)
    private notificationRepository: Repository<Notification>,
    @InjectRepository(Tutor)
    private tutorRepository: Repository<Tutor>,
  ) {}

  /**
   * Crear una notificación para un tutor específico
   */
  async create(
    tutorId: number,
    createNotificationDto: CreateNotificationDto,
  ): Promise<Notification> {
    const tutor = await this.tutorRepository.findOne({
      where: { id: tutorId },
    });

    if (!tutor) {
      throw new NotFoundException(`Tutor con ID ${tutorId} no encontrado`);
    }

    const notification = this.notificationRepository.create({
      ...createNotificationDto,
      tipo: createNotificationDto.tipo || 'info',
      tutor,
    });

    try {
      return await this.notificationRepository.save(notification);
    } catch (error) {
      throw new BadRequestException('Error al crear la notificación');
    }
  }

  /**
   * Obtener todas las notificaciones de un tutor con filtros opcionales
   */
  async findAllByTutor(
    tutorId: number,
    queryDto: QueryNotificationsDto,
  ): Promise<{
    notifications: Notification[];
    total: number;
    unreadCount: number;
  }> {
    const { tipo, leida, limit = 50, offset = 0 } = queryDto;

    const queryBuilder = this.notificationRepository
      .createQueryBuilder('notification')
      .leftJoinAndSelect('notification.tutor', 'tutor')
      .where('tutor.id = :tutorId', { tutorId })
      .orderBy('notification.createdAt', 'DESC')
      .take(limit)
      .skip(offset);

    // Filtros opcionales
    if (tipo) {
      queryBuilder.andWhere('notification.tipo = :tipo', { tipo });
    }

    if (leida !== undefined) {
      queryBuilder.andWhere('notification.leida = :leida', { leida });
    }

    const [notifications, total] = await queryBuilder.getManyAndCount();

    // Obtener conteo de no leídas
    const unreadCount = await this.notificationRepository
      .createQueryBuilder('notification')
      .where('notification.tutorId = :tutorId', { tutorId })
      .andWhere('notification.leida = :leida', { leida: false })
      .getCount();

    return {
      notifications,
      total,
      unreadCount,
    };
  }

  /**
   * Obtener una notificación específica
   */
  async findOne(id: number, tutorId: number): Promise<Notification> {
    const notification = await this.notificationRepository
      .createQueryBuilder('notification')
      .leftJoinAndSelect('notification.tutor', 'tutor')
      .where('notification.id = :id', { id })
      .andWhere('notification.tutorId = :tutorId', { tutorId })
      .getOne();

    if (!notification) {
      throw new NotFoundException(`Notificación con ID ${id} no encontrada`);
    }

    return notification;
  }

  /**
   * Marcar una o varias notificaciones como leídas
   */
  async markAsRead(
    notificationIds: number[],
    tutorId: number,
  ): Promise<{ updated: number }> {
    if (!notificationIds || notificationIds.length === 0) {
      throw new BadRequestException(
        'Debe proporcionar al menos un ID de notificación',
      );
    }

    // Verificar que todas las notificaciones pertenecen al tutor
    const notifications = await this.notificationRepository
      .createQueryBuilder('notification')
      .leftJoinAndSelect('notification.tutor', 'tutor')
      .where('notification.id IN (:...notificationIds)', { notificationIds })
      .andWhere('tutor.id = :tutorId', { tutorId })
      .getMany();

    if (notifications.length !== notificationIds.length) {
      throw new ForbiddenException(
        'No tienes permiso para modificar algunas de estas notificaciones',
      );
    }

    const result = await this.notificationRepository
      .createQueryBuilder()
      .update(Notification)
      .set({ leida: true })
      .where('id IN (:...notificationIds)', { notificationIds })
      .andWhere('tutorId = :tutorId', { tutorId })
      .andWhere('leida = :leida', { leida: false })
      .execute();

    return { updated: result.affected || 0 };
  }

  /**
   * Marcar todas las notificaciones como leídas
   */
  async markAllAsRead(tutorId: number): Promise<{ updated: number }> {
    const result = await this.notificationRepository
      .createQueryBuilder()
      .update(Notification)
      .set({ leida: true })
      .where('tutorId = :tutorId', { tutorId })
      .andWhere('leida = :leida', { leida: false })
      .execute();

    return { updated: result.affected || 0 };
  }

  /**
   * Eliminar una notificación
   */
  async remove(id: number, tutorId: number): Promise<void> {
    const notification = await this.findOne(id, tutorId);
    await this.notificationRepository.remove(notification);
  }

  /**
   * Eliminar múltiples notificaciones
   */
  async removeMany(
    notificationIds: number[],
    tutorId: number,
  ): Promise<{ deleted: number }> {
    if (!notificationIds || notificationIds.length === 0) {
      throw new BadRequestException(
        'Debe proporcionar al menos un ID de notificación',
      );
    }

    // Verificar que todas las notificaciones pertenecen al tutor
    const notifications = await this.notificationRepository
      .createQueryBuilder('notification')
      .where('notification.id IN (:...notificationIds)', { notificationIds })
      .andWhere('notification.tutorId = :tutorId', { tutorId })
      .getMany();

    if (notifications.length === 0) {
      return { deleted: 0 };
    }

    if (notifications.length !== notificationIds.length) {
      throw new ForbiddenException(
        'No tienes permiso para eliminar algunas de estas notificaciones',
      );
    }

    await this.notificationRepository.remove(notifications);

    return { deleted: notifications.length };
  }

  /**
   * Obtener el conteo de notificaciones no leídas
   */
  async getUnreadCount(tutorId: number): Promise<{ count: number }> {
    const count = await this.notificationRepository
      .createQueryBuilder('notification')
      .where('notification.tutorId = :tutorId', { tutorId })
      .andWhere('notification.leida = :leida', { leida: false })
      .getCount();

    return { count };
  }

  /**
   * Limpiar notificaciones antiguas (más de 30 días)
   */
  async cleanOldNotifications(days: number = 30): Promise<{ deleted: number }> {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - days);

    const result = await this.notificationRepository
      .createQueryBuilder()
      .delete()
      .where('created_at < :cutoffDate', { cutoffDate })
      .andWhere('leida = true')
      .execute();

    return { deleted: result.affected || 0 };
  }

  /**
   * Enviar notificación push via FCM
   */
  async sendPushNotification(
    userId: number,
    title: string,
    body: string,
    data: { type: string; childId?: number; [key: string]: any },
  ): Promise<void> {
    // Verificar si Firebase está inicializado
    if (admin.apps.length === 0) {
      console.warn('⚠️ Firebase not initialized - skipping push notification');
      return;
    }

    const tutor = await this.tutorRepository.findOne({
      where: { id: userId },
    });

    if (!tutor || !tutor.fcmToken) {
      console.log(`No FCM token for user ${userId}`);
      return;
    }

    const message = {
      notification: {
        title,
        body,
      },
      data: {
        type: data.type,
        childId: data.childId?.toString() || '',
        ...Object.fromEntries(
          Object.entries(data).map(([key, value]) => [key, String(value)])
        ),
      },
      token: tutor.fcmToken,
    };

    try {
      await admin.messaging().send(message);
      console.log('Push notification sent successfully');
    } catch (error) {
      console.error('Error sending push notification:', error);
      // Si el token es inválido, limpiarlo
      if (error.code === 'messaging/registration-token-not-registered') {
        await this.tutorRepository.update(userId, { fcmToken: null });
      }
    }
  }
}
