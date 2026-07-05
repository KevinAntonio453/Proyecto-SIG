import { IsString, MinLength, MaxLength, Matches } from 'class-validator';

export class LoginCodigoDto {
  @IsString()
  @MinLength(6)
  @MaxLength(6)
  @Matches(/^[A-Z0-9]{6}$/, {
    message: 'El código debe tener 6 caracteres alfanuméricos en mayúsculas',
  })
  codigo: string;
}
