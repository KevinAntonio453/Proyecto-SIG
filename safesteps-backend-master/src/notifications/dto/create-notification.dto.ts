import { IsString, IsOptional, IsNotEmpty, MaxLength } from 'class-validator';

export class CreateNotificationDto {
  @IsString()
  @IsNotEmpty({ message: 'El mensaje es requerido' })
  @MaxLength(500, { message: 'El mensaje no puede exceder 500 caracteres' })
  mensaje: string;

  @IsString()
  @IsOptional()
  tipo?: string;
}
