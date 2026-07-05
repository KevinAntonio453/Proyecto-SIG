import { IsArray, IsInt } from 'class-validator';

export class MarkReadDto {
  @IsArray()
  @IsInt({ each: true, message: 'Cada ID debe ser un número entero' })
  notificationIds: number[];
}
