import { IsEmail, IsString, MinLength, IsNotEmpty, IsOptional, IsNumber, Min, Max, IsInt } from 'class-validator';

export class RegisterHijoByTutorDto {
  @IsString()
  @IsNotEmpty({ message: 'El nombre es requerido' })
  @MinLength(3, { message: 'El nombre debe tener al menos 3 caracteres' })
  nombre: string;

  @IsOptional()
  @IsString()
  @MinLength(2, { message: 'El apellido debe tener al menos 2 caracteres' })
  apellido?: string;

  @IsOptional()
  @IsString()
  @MinLength(7, { message: 'El teléfono debe tener al menos 7 caracteres' })
  telefono?: string;
}
