import { Controller, Post, Body, Get, Param, Patch, Delete, UseGuards, Request } from '@nestjs/common';
import { ZonasSegurasService } from './zonas-seguras.service';
import { CreateZonaSeguraDto } from './dto/create-zona-segura.dto';
import { UpdateZonaSeguraDto } from './dto/update-zona-segura.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@Controller('zonas-seguras')
@UseGuards(JwtAuthGuard)
export class ZonasSegurasController {
  constructor(private readonly zonasSegurasService: ZonasSegurasService) {}

  @Post()
  create(@Body() createDto: CreateZonaSeguraDto, @Request() req) {
    return this.zonasSegurasService.create(createDto, req.user);
  }

  @Get()
  findAll(@Request() req) {
    return this.zonasSegurasService.findAllByTutor(req.user.id);
  }

  @Get(':id')
  findOne(@Param('id') id: string, @Request() req) {
    return this.zonasSegurasService.findOne(+id, req.user);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() updateDto: UpdateZonaSeguraDto, @Request() req) {
    return this.zonasSegurasService.update(+id, updateDto, req.user);
  }

  @Delete(':id')
  remove(@Param('id') id: string, @Request() req) {
    return this.zonasSegurasService.remove(+id, req.user);
  }
}
