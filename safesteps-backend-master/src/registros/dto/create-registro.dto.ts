import { IsDate, IsNumber, IsInt, IsBoolean, IsOptional } from 'class-validator';
import { Type } from 'class-transformer';

export class CreateRegistroDto {
  @IsDate()
  @Type(() => Date)
  hora: Date;

  @IsNumber()
  latitud: number;

  @IsNumber()
  longitud: number;

  @IsInt()
  hijoId: number;

  @IsBoolean()
  @IsOptional()
  fueOffline?: boolean;
}