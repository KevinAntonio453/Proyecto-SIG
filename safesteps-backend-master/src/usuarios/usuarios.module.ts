import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TutorController } from './tutor.controller';
import { HijoController } from './hijo.controller';
import { TutorService } from './tutor.service';
import { HijoService } from './hijo.service';
import { Tutor } from './entities/tutor.entity';
import { Hijo } from './entities/hijo.entity';
import { User } from '../auth/entities/user.entity';
import { ZonasSegurasModule } from '../zonas-seguras/zonas-seguras.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Tutor, Hijo, User]),
    forwardRef(() => ZonasSegurasModule),
    forwardRef(() => NotificationsModule),
  ],
  controllers: [TutorController, HijoController],
  providers: [TutorService, HijoService],
  exports: [TutorService, HijoService],
})
export class UsuariosModule {}
