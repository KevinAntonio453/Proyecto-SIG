import {
    WebSocketGateway,
    WebSocketServer,
    SubscribeMessage,
    OnGatewayConnection,
    OnGatewayDisconnect,
    ConnectedSocket,
    MessageBody,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Hijo } from '../usuarios/entities/hijo.entity';
import { HijoService } from '../usuarios/hijo.service';
import { Inject, forwardRef } from '@nestjs/common';

@WebSocketGateway({
    cors: {
        origin: '*', // Permite conexiones WebSocket desde cualquier origen
        methods: ['GET', 'POST'],
        credentials: true,
    },
    transports: ['websocket', 'polling'], // Soporta ambos transportes
})
export class UbicacionGateway implements OnGatewayConnection, OnGatewayDisconnect {
    @WebSocketServer() server: Server;

    constructor(
        private jwtService: JwtService,
        private configService: ConfigService,
        @InjectRepository(Hijo)
        private hijoRepository: Repository<Hijo>,
        @Inject(forwardRef(() => HijoService))
        private hijoService: HijoService,
    ) { }

    async handleConnection(client: Socket) {
        try {
            // Intentar obtener el token de múltiples fuentes
            let token = client.handshake.headers.authorization?.split(' ')[1];
            
            // Si no está en headers, buscar en auth
            if (!token && client.handshake.auth?.token) {
                token = client.handshake.auth.token;
            }
            
            // Si no está en auth, buscar en query
            if (!token && client.handshake.query?.token) {
                token = client.handshake.query.token as string;
            }
            
            if (!token) {
                console.log('❌ Cliente conectado sin token:', client.id);
                client.disconnect();
                return;
            }

            const payload = this.jwtService.verify(token, {
                secret: this.configService.get<string>('JWT_SECRET', 'your-secret-key'),
            });

            client.data.user = payload;
            console.log(`✅ Cliente conectado: ${client.id}, Usuario ID: ${payload.sub}, Tipo: ${payload.tipo}`);

            // Si es un hijo, unirlo automáticamente a su sala y notificar que está online
            if (payload.tipo === 'hijo') {
                const room = `hijo_${payload.sub}`;
                client.join(room);
                
                // Obtener device del handshake si está disponible
                const device = client.handshake.query?.device as string || 'Unknown';
                client.data.device = device;
                
                console.log(`👶 Hijo ${payload.sub} unido automáticamente a sala ${room} (${device})`);
                
                // Notificar a los tutores que el hijo está online
                this.server.to(room).emit('childStatusChanged', {
                    childId: payload.sub,
                    online: true,
                    device: device,
                    timestamp: new Date().toISOString(),
                });
            }
        } catch (e) {
            console.log('❌ Conexión no autorizada:', e.message);
            client.disconnect();
        }
    }

    handleDisconnect(client: Socket) {
        const user = client.data.user;
        const device = client.data.device || 'Unknown';
        console.log(`🔌 Cliente desconectado: ${client.id}`);
        
        // Si era un hijo, notificar a los tutores que está offline
        if (user && user.tipo === 'hijo') {
            const room = `hijo_${user.sub}`;
            console.log(`👶 Hijo ${user.sub} desconectado, notificando a sala ${room} (${device})`);
            
            this.server.to(room).emit('childStatusChanged', {
                childId: user.sub,
                online: false,
                device: device,
                timestamp: new Date().toISOString(),
            });
        }
    }

    @SubscribeMessage('joinChildRoom')
    async handleJoinChildRoom(@ConnectedSocket() client: Socket, @MessageBody() data: { childId: string }) {
        // Verificar que el usuario sea un tutor
        const user = client.data.user;
        if (!user) {
            client.emit('error', { message: 'No autenticado' });
            return;
        }

        // Verificar que este tutor tiene permiso para ver a este hijo
        const childIdNum = parseInt(data.childId, 10);
        if (isNaN(childIdNum)) {
            client.emit('error', { message: 'ID de hijo inválido' });
            return;
        }
        
        const hijo = await this.hijoRepository.findOne({
            where: { id: childIdNum },
            relations: ['tutores'],
        });

        if (!hijo) {
            client.emit('error', { message: 'Hijo no encontrado' });
            return;
        }

        const esTutorDelHijo = hijo.tutores.some(tutor => tutor.id === user.sub);
        if (!esTutorDelHijo) {
            client.emit('error', { message: 'No tienes permisos para ver a este hijo' });
            console.log(`❌ Tutor ${user.sub} bloqueado al intentar unirse a sala de hijo ${data.childId} (no vinculado)`);
            return;
        }

        const room = `hijo_${data.childId}`;
        client.join(room);
        console.log(`Tutor ${user.sub} unido a sala ${room}`);
        client.emit('joined', { room, childId: data.childId });
    }

    @SubscribeMessage('leaveChildRoom')
    handleLeaveChildRoom(@ConnectedSocket() client: Socket, @MessageBody() data: { childId: string }) {
        const room = `hijo_${data.childId}`;
        client.leave(room);
        console.log(`Cliente ${client.id} dejó sala ${room}`);
        client.emit('left', { room, childId: data.childId });
    }

    @SubscribeMessage('updateLocation')
    async handleUpdateLocation(
        @ConnectedSocket() client: Socket,
        @MessageBody() data: { lat: number; lng: number; battery: number; status: string; device?: string }
    ) {
        const user = client.data.user;
        
        // Verificar que es un hijo autenticado
        if (!user || user.tipo !== 'hijo') {
            console.log('Intento de actualización no autorizado - no es hijo');
            client.emit('error', { message: 'No autorizado para actualizar ubicación' });
            return;
        }

        // Usar el ID del JWT directamente (más seguro que confiar en el cliente)
        const childId = String(user.sub);
        const room = `hijo_${childId}`;

        // Emitir a todos en la sala (tutores que están viendo a este hijo)
        this.server.to(room).emit('locationUpdated', {
            childId: childId,
            lat: data.lat,
            lng: data.lng,
            battery: data.battery,
            status: data.status,
            device: data.device || 'Unknown', // Dispositivo del hijo
            timestamp: new Date().toISOString(),
        });
        
        console.log(`📍 Ubicación actualizada para hijo ${childId}: ${data.lat}, ${data.lng} (${data.device || 'Unknown'})`);

        // Persistir en base de datos
        try {
            await this.hijoRepository.update(childId, {
                latitud: data.lat,
                longitud: data.lng,
                ultimaconexion: new Date(),
            });
        } catch (e) {
            console.error('Error actualizando ubicación en BD:', e);
        }
    }

    // Método para que el hijo notifique que está activo
    @SubscribeMessage('childOnline')
    handleChildOnline(@ConnectedSocket() client: Socket) {
        const user = client.data.user;
        if (!user || user.tipo !== 'hijo') {
            return;
        }

        const room = `hijo_${user.sub}`;
        this.server.to(room).emit('childStatusChanged', {
            childId: user.sub,
            online: true,
            timestamp: new Date().toISOString(),
        });
        console.log(`Hijo ${user.sub} está en línea`);
    }

    // Método para que el hijo notifique que se va offline (antes de desconectar)
    @SubscribeMessage('childOffline')
    handleChildOffline(@ConnectedSocket() client: Socket) {
        const user = client.data.user;
        if (!user || user.tipo !== 'hijo') {
            return;
        }

        const room = `hijo_${user.sub}`;
        this.server.to(room).emit('childStatusChanged', {
            childId: user.sub,
            online: false,
            timestamp: new Date().toISOString(),
        });
        console.log(`Hijo ${user.sub} notificó que está offline`);
    }

    // Método para solicitar ubicación actual del hijo
    @SubscribeMessage('requestLocation')
    async handleRequestLocation(@ConnectedSocket() client: Socket, @MessageBody() data: { childId: string }) {
        const user = client.data.user;
        if (!user) {
            client.emit('error', { message: 'No autenticado' });
            return;
        }

        const childIdNum = parseInt(data.childId, 10);
        if (isNaN(childIdNum)) {
            client.emit('error', { message: 'ID de hijo inválido' });
            return;
        }
        
        const hijo = await this.hijoRepository.findOne({
            where: { id: childIdNum },
            relations: ['tutores'],
        });

        if (!hijo) {
            client.emit('error', { message: 'Hijo no encontrado' });
            return;
        }

        const esTutorDelHijo = hijo.tutores.some(tutor => tutor.id === user.sub);
        if (!esTutorDelHijo) {
            client.emit('error', { message: 'No tienes permisos para solicitar ubicación de este hijo' });
            console.log(`❌ Tutor ${user.sub} bloqueado al intentar solicitar ubicación de hijo ${data.childId} (no vinculado)`);
            return;
        }

        const room = `hijo_${data.childId}`;
        // Enviar solicitud al hijo para que envíe su ubicación
        this.server.to(room).emit('locationRequested', {
            requestedBy: user.sub,
            childId: data.childId,
        });
        console.log(`Tutor ${user.sub} solicitó ubicación del hijo ${data.childId}`);
    }

    // Método para recibir alertas de pánico del hijo
    @SubscribeMessage('panicAlert')
    async handlePanicAlert(
        @ConnectedSocket() client: Socket,
        @MessageBody() data: { lat: number; lng: number; timestamp?: string }
    ) {
        const user = client.data.user;
        
        // Verificar que es un hijo autenticado
        if (!user || user.tipo !== 'hijo') {
            console.log('Intento de alerta de pánico no autorizado');
            client.emit('error', { message: 'No autorizado para enviar alerta' });
            return;
        }

        // Usar el ID del JWT directamente
        const childId = String(user.sub);
        const room = `hijo_${childId}`;

        // Emitir alerta a todos los tutores en la sala (broadcast en vivo por WS)
        this.server.to(room).emit('panicAlert', {
            childId: childId,
            lat: data.lat,
            lng: data.lng,
            timestamp: data.timestamp || new Date().toISOString(),
        });
        
        console.log(`🚨 ALERTA DE PÁNICO del hijo ${childId}: ${data.lat}, ${data.lng}`);

        // Actualizar coordenadas en BD y persistir/enviar SOS por notificaciones push
        try {
            await this.hijoRepository.update(childId, {
                latitud: data.lat,
                longitud: data.lng,
                ultimaconexion: new Date(),
            });

            await this.hijoService.enviarAlertaSOS(user.sub, user.sub);
            console.log(`✅ Alerta de pánico persistida y notificaciones push despachadas para hijo ${childId}`);
        } catch (e) {
            console.error('Error al persistir y notificar SOS:', e.message);
        }
    }
}
