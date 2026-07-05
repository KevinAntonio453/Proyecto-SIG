import { PartialType } from '@nestjs/mapped-types';
import { CreateZonaSeguraDto } from './create-zona-segura.dto';
import { IsArray, IsInt, ArrayNotEmpty, IsOptional } from 'class-validator';

export class UpdateZonaSeguraDto extends PartialType(CreateZonaSeguraDto) {
  @IsArray()
  @IsOptional()
  @IsInt({ each: true })
  hijosIds?: number[];
}
