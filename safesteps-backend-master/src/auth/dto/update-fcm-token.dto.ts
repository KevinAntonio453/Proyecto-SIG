import { IsString, IsNotEmpty } from 'class-validator';

export class UpdateFcmTokenDto {
  @IsString()
  @IsNotEmpty({ message: 'El FCM token es requerido' })
  fcmToken: string;
}