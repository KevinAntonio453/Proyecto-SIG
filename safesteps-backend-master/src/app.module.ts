import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { AuthModule } from './auth/auth.module';
import { UsuariosModule } from './usuarios/usuarios.module';
import { NotificationsModule } from './notifications/notifications.module';
import { User } from './auth/entities/user.entity';
import { Tutor } from './usuarios/entities/tutor.entity';
import { Hijo } from './usuarios/entities/hijo.entity';
import { Notification } from './notifications/entities/notification.entity';
import { ZonasSegurasModule } from './zonas-seguras/zonas-seguras.module';
import { ZonaSegura } from './zonas-seguras/entities/zona-segura.entity';
import { RegistrosModule } from './registros/registros.module';
import { Registro } from './registros/entities/registro.entity';
import { UbicacionModule } from './ubicacion/ubicacion.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: (configService: ConfigService) => {
        const isProd = configService.get('NODE_ENV') === 'production';
        const dbUrl = configService.get('DATABASE_URL');

        const options: any = {
          type: 'postgres',
          entities: [User, Tutor, Hijo, Notification, ZonaSegura, Registro],
          synchronize: !isProd, // Desactivado en producción por seguridad
          logging: !isProd,
          ssl: isProd || configService.get('DB_SSL') === 'true'
            ? { rejectUnauthorized: false } // Requerido por Render Postgres
            : false,
        };

        if (dbUrl) {
          options.url = dbUrl;
        } else {
          options.host = configService.get('DB_HOST');
          options.port = Number(configService.get('DB_PORT')) || 5432;
          options.username = configService.get('DB_USERNAME');
          options.password = configService.get('DB_PASSWORD');
          options.database = configService.get('DB_NAME');
        }

        return options;
      },
      inject: [ConfigService],
    }),
    AuthModule,
    UsuariosModule,
    NotificationsModule,
    ZonasSegurasModule,
    RegistrosModule,
    UbicacionModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
