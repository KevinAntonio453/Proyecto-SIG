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
import { TutorService } from './tutor.service';
import { CreateTutorDto } from './dto/create-tutor.dto';
import { RegisterHijoByTutorDto } from './dto/register-hijo-by-tutor.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { UpdateTutorDto } from './dto/update-tutor.dto';
import { GetUser } from '../common/decorators/get-user.decorator';
import { User } from '../auth/entities/user.entity';

@Controller('tutores')
@UseGuards(JwtAuthGuard)
export class TutorController {
  constructor(private readonly tutorService: TutorService) {}

  @Post()
  create(@Body() createTutorDto: CreateTutorDto) {
    return this.tutorService.create(createTutorDto);
  }

  /**
   * Alias de me/hijos - Registra un nuevo hijo para el tutor autenticado
   */
  @Post('registrar-hijo')
  registrarHijo(
    @GetUser() user: User,
    @Body() registerHijoDto: RegisterHijoByTutorDto,
  ) {
    return this.tutorService.registerHijoForAuthenticatedTutor(user.id, registerHijoDto);
  }

  /**
   * Registra un nuevo hijo para el tutor autenticado
   * El tutor se obtiene automáticamente del JWT
   * @param user - Usuario autenticado (extraído del JWT)
   * @param registerHijoDto - Datos del hijo a registrar
   */
  @Post('me/hijos')
  registerHijo(
    @GetUser() user: User,
    @Body() registerHijoDto: RegisterHijoByTutorDto,
  ) {
    return this.tutorService.registerHijoForAuthenticatedTutor(user.id, registerHijoDto);
  }

  /**
   * Obtiene los hijos del tutor autenticado
   * El tutor se obtiene automáticamente del JWT
   */
  @Get('me/hijos')
  getMyHijos(@GetUser() user: User) {
    return this.tutorService.getHijos(user.id);
  }

  @Get()
  findAll() {
    return this.tutorService.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string, @GetUser() user: User) {
    if (user.id !== +id) {
      throw new ForbiddenException('No tienes permiso para ver los datos de este tutor');
    }
    return this.tutorService.findOne(+id);
  }

  @Get(':id/hijos')
  getHijos(@Param('id') id: string, @GetUser() user: User) {
    if (user.id !== +id) {
      throw new ForbiddenException('No tienes permiso para ver los hijos de este tutor');
    }
    return this.tutorService.getHijos(+id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() updateTutorDto: UpdateTutorDto, @GetUser() user: User) {
    if (user.id !== +id) {
      throw new ForbiddenException('No tienes permiso para actualizar este tutor');
    }
    return this.tutorService.update(+id, updateTutorDto);
  }

  @Delete(':id')
  remove(@Param('id') id: string, @GetUser() user: User) {
    if (user.id !== +id) {
      throw new ForbiddenException('No tienes permiso para eliminar este tutor');
    }
    return this.tutorService.remove(+id);
  }

  @Post(':tutorId/hijos/:hijoId')
  addHijo(@Param('tutorId') tutorId: string, @Param('hijoId') hijoId: string, @GetUser() user: User) {
    if (user.id !== +tutorId) {
      throw new ForbiddenException('No tienes permiso para vincular hijos a este tutor');
    }
    return this.tutorService.addHijo(+tutorId, +hijoId);
  }

  @Delete(':tutorId/hijos/:hijoId')
  removeHijo(@Param('tutorId') tutorId: string, @Param('hijoId') hijoId: string, @GetUser() user: User) {
    if (user.id !== +tutorId) {
      throw new ForbiddenException('No tienes permiso para desvincular hijos de este tutor');
    }
    return this.tutorService.removeHijo(+tutorId, +hijoId);
  }
}
