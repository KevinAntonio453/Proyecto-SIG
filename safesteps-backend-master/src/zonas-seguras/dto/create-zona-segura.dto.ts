import { IsString, IsOptional, IsNotEmpty, IsObject, IsArray, ArrayNotEmpty, IsInt } from 'class-validator';

export class CreateZonaSeguraDto {
  @IsString()
  @IsNotEmpty()
  nombre: string;

  @IsString()
  @IsOptional()
  descripcion?: string;

  @IsObject()
  @IsNotEmpty()
  poligono: any; // Se recomienda GeoJSON, se puede ajustar el tipo luego

  @IsArray()
  @ArrayNotEmpty()
  @IsInt({ each: true })
  hijosIds: number[];
}
