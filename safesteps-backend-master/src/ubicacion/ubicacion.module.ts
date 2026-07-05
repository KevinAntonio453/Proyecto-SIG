import { Module } from '@nestjs/common';
import { UbicacionGateway } from './ubicacion.gateway';
import { JwtModule } from '@nestjs/jwt';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Hijo } from '../usuarios/entities/hijo.entity';

@Module({
    imports: [
        ConfigModule,
        JwtModule.registerAsync({
            imports: [ConfigModule],
            useFactory: async (configService: ConfigService) => ({
                secret: configService.get<string>('JWT_SECRET', 'your-secret-key'),
                signOptions: { expiresIn: '7d' },
            }),
            inject: [ConfigService],
        }),
        TypeOrmModule.forFeature([Hijo]),
    ],
    providers: [UbicacionGateway],
    exports: [UbicacionGateway],
})
export class UbicacionModule { }
