import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
  UseGuards,
  ForbiddenException,
} from '@nestjs/common';
import { HijoService } from './hijo.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreateHijoDto } from './dto/create-hijo.dto';
import { UpdateHijoDto } from './dto/update-hijo.dto';
import { UpdateLocationDto } from './dto/update-location.dto';
import { VincularCodigoDto } from './dto/vincular-codigo.dto';
import { GetUser } from '../common/decorators/get-user.decorator';
import { User } from '../auth/entities/user.entity';

@Controller('hijos')
export class HijoController {
  constructor(private readonly hijoService: HijoService) {}

  @Post()
  @UseGuards(JwtAuthGuard)
  create(@Body() createHijoDto: CreateHijoDto) {
    return this.hijoService.create(createHijoDto);
  }

  @Get()
  @UseGuards(JwtAuthGuard)
  findAll() {
    throw new ForbiddenException('No tienes permiso para listar todos los hijos del sistema');
  }

  @Get(':id')
  @UseGuards(JwtAuthGuard)
  async findOne(@Param('id') id: string, @GetUser() user: User) {
    const hijoId = +id;
    if (user.tipo === 'hijo' && user.id === hijoId) {
      return this.hijoService.findOne(hijoId);
    }
    if (user.tipo === 'tutor') {
      const hasAccess = await this.hijoService.belongsToTutor(hijoId, user.id);
      if (hasAccess) {
        return this.hijoService.findOne(hijoId);
      }
    }
    throw new ForbiddenException('No tienes permisos para acceder a los datos de este hijo');
  }

  @Patch(':id')
  @UseGuards(JwtAuthGuard)
  async update(@Param('id') id: string, @Body() updateHijoDto: UpdateHijoDto, @GetUser() user: User) {
    const hijoId = +id;
    if (user.tipo === 'hijo' && user.id === hijoId) {
      return this.hijoService.update(hijoId, updateHijoDto);
    }
    if (user.tipo === 'tutor') {
      const hasAccess = await this.hijoService.belongsToTutor(hijoId, user.id);
      if (hasAccess) {
        return this.hijoService.update(hijoId, updateHijoDto);
      }
    }
    throw new ForbiddenException('No tienes permisos para actualizar los datos de este hijo');
  }

  @Patch(':id/location')
  @UseGuards(JwtAuthGuard)
  updateLocation(@Param('id') id: string, @Body() updateLocationDto: UpdateLocationDto, @GetUser() user: User) {
    const hijoId = +id;
    if (user.tipo !== 'hijo' || user.id !== hijoId) {
      throw new ForbiddenException('Solo el propio hijo puede actualizar su ubicación');
    }
    return this.hijoService.updateLocation(hijoId, updateLocationDto);
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard)
  async remove(@Param('id') id: string, @GetUser() user: User) {
    const hijoId = +id;
    if (user.tipo === 'tutor') {
      const hasAccess = await this.hijoService.belongsToTutor(hijoId, user.id);
      if (hasAccess) {
        return this.hijoService.remove(hijoId);
      }
    }
    throw new ForbiddenException('Solo un tutor vinculado puede eliminar a este hijo');
  }

  /**
   * Vincular dispositivo del hijo usando código
   * Este endpoint NO requiere autenticación (es para el primer acceso)
   */
  @Post('vincular')
  vincularConCodigo(@Body() vincularDto: VincularCodigoDto) {
    return this.hijoService.vincularConCodigo(
      vincularDto.codigo,
      vincularDto.email,
      vincularDto.password,
    );
  }

  /**
   * Verificar código de vinculación (sin autenticación)
   * Retorna info básica del hijo para confirmar que es el correcto
   */
  @Get('verificar-codigo/:codigo')
  verificarCodigo(@Param('codigo') codigo: string) {
    return this.hijoService.findByCodigo(codigo);
  }

  /**
   * Regenerar código de vinculación
   * Solo el tutor dueño del hijo puede regenerar el código
   */
  @Post(':id/regenerar-codigo')
  @UseGuards(JwtAuthGuard)
  regenerarCodigo(@Param('id') id: string, @GetUser() user: any) {
    return this.hijoService.regenerarCodigo(+id, user.id);
  }

  /**
   * Botón SOS - Enviar alerta de pánico a tutores
   */
  @Post(':id/sos')
  @UseGuards(JwtAuthGuard)
  enviarAlertaSOS(@Param('id') id: string, @GetUser() user: any) {
    return this.hijoService.enviarAlertaSOS(+id, user.id);
  }
}
