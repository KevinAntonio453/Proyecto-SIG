import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
  UseGuards,
} from '@nestjs/common';
import { HijoService } from './hijo.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreateHijoDto } from './dto/create-hijo.dto';
import { UpdateHijoDto } from './dto/update-hijo.dto';
import { UpdateLocationDto } from './dto/update-location.dto';
import { VincularCodigoDto } from './dto/vincular-codigo.dto';
import { GetUser } from '../common/decorators/get-user.decorator';

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
    return this.hijoService.findAll();
  }

  @Get(':id')
  @UseGuards(JwtAuthGuard)
  findOne(@Param('id') id: string) {
    return this.hijoService.findOne(+id);
  }

  @Patch(':id')
  @UseGuards(JwtAuthGuard)
  update(@Param('id') id: string, @Body() updateHijoDto: UpdateHijoDto) {
    return this.hijoService.update(+id, updateHijoDto);
  }

  @Patch(':id/location')
  @UseGuards(JwtAuthGuard)
  updateLocation(@Param('id') id: string, @Body() updateLocationDto: UpdateLocationDto) {
    return this.hijoService.updateLocation(+id, updateLocationDto);
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard)
  remove(@Param('id') id: string) {
    return this.hijoService.remove(+id);
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
