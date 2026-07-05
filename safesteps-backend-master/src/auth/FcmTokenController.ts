import { Controller, Patch, Body, UseGuards, HttpCode, HttpStatus } from '@nestjs/common';
import { AuthService } from './auth.service';
import { UpdateFcmTokenDto } from './dto/update-fcm-token.dto';
import { JwtAuthGuard } from './jwt-auth.guard';
import { GetUser } from '../common/decorators/get-user.decorator';
import { User } from './entities/user.entity';

@Controller('users')
@UseGuards(JwtAuthGuard)
export class FcmTokenController {
  constructor(private readonly authService: AuthService) {
    console.log('FcmTokenController instantiated');
  }

  @Patch('fcm-token')
  @HttpCode(HttpStatus.OK)
  async updateFcmToken(@GetUser() user: User, @Body() updateFcmTokenDto: UpdateFcmTokenDto) {
    await this.authService.updateFcmToken(user.id, updateFcmTokenDto.fcmToken);
    return { message: 'FCM Token updated successfully' };
  }
}