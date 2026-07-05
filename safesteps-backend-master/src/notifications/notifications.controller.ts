import {
  Controller,
  Get,
  Post,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  ParseIntPipe,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { CreateNotificationDto } from './dto/create-notification.dto';
import { QueryNotificationsDto } from './dto/query-notifications.dto';
import { MarkReadDto } from './dto/mark-read.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { GetUser } from '../common/decorators/get-user.decorator';
import { User } from '../auth/entities/user.entity';

@Controller('notifications')
@UseGuards(JwtAuthGuard)
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  /**
   * Obtener todas las notificaciones del tutor autenticado
   * GET /notifications
   * Query params: tipo, isRead, limit, offset
   */
  @Get()
  async findAll(
    @GetUser() user: User,
    @Query() queryDto: QueryNotificationsDto,
  ) {
    return this.notificationsService.findAllByTutor(user.id, queryDto);
  }

  /**
   * Obtener el conteo de notificaciones no leídas
   * GET /notifications/unread/count
   */
  @Get('unread/count')
  async getUnreadCount(@GetUser() user: User) {
    return this.notificationsService.getUnreadCount(user.id);
  }

  /**
   * Obtener una notificación específica
   * GET /notifications/:id
   */
  @Get(':id')
  async findOne(
    @Param('id', ParseIntPipe) id: number,
    @GetUser() user: User,
  ) {
    return this.notificationsService.findOne(id, user.id);
  }

  /**
   * Crear una notificación (para testing/admin)
   * POST /notifications
   */
  @Post()
  @HttpCode(HttpStatus.CREATED)
  async create(
    @GetUser() user: User,
    @Body() createNotificationDto: CreateNotificationDto,
  ) {
    return this.notificationsService.create(user.id, createNotificationDto);
  }

  /**
   * Marcar notificaciones como leídas
   * POST /notifications/mark-read
   * Body: { notificationIds: [1, 2, 3] }
   */
  @Post('mark-read')
  @HttpCode(HttpStatus.OK)
  async markAsRead(
    @GetUser() user: User,
    @Body() markReadDto: MarkReadDto,
  ) {
    return this.notificationsService.markAsRead(
      markReadDto.notificationIds,
      user.id,
    );
  }

  /**
   * Marcar todas las notificaciones como leídas
   * POST /notifications/mark-all-read
   */
  @Post('mark-all-read')
  @HttpCode(HttpStatus.OK)
  async markAllAsRead(@GetUser() user: User) {
    return this.notificationsService.markAllAsRead(user.id);
  }

  /**
   * Eliminar una notificación
   * DELETE /notifications/:id
   */
  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(
    @Param('id', ParseIntPipe) id: number,
    @GetUser() user: User,
  ) {
    await this.notificationsService.remove(id, user.id);
  }

  /**
   * Eliminar múltiples notificaciones
   * DELETE /notifications
   * Body: { notificationIds: [1, 2, 3] }
   */
  @Delete()
  @HttpCode(HttpStatus.OK)
  async removeMany(
    @GetUser() user: User,
    @Body() markReadDto: MarkReadDto,
  ) {
    return this.notificationsService.removeMany(
      markReadDto.notificationIds,
      user.id,
    );
  }
}
