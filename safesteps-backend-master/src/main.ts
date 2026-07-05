import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';
import * as admin from 'firebase-admin';
import * as path from 'path';
import * as fs from 'fs';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  
  // ===== CONFIGURACIÓN CORS COMPLETA =====
  // Permite conexiones desde cualquier origen (frontend desplegado en cualquier lugar)
  const corsOrigins = process.env.CORS_ORIGINS 
    ? process.env.CORS_ORIGINS.split(',').map(origin => origin.trim())
    : '*'; // Por defecto permite todos los orígenes

  app.enableCors({
    origin: corsOrigins, // Orígenes permitidos (string, array, o '*')
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'], // Métodos HTTP permitidos
    allowedHeaders: [
      'Content-Type',
      'Authorization',
      'Accept',
      'Origin',
      'X-Requested-With',
      'Access-Control-Allow-Origin',
      'Access-Control-Allow-Headers',
      'Access-Control-Allow-Methods',
    ],
    credentials: true, // Permite enviar cookies/tokens de autenticación
    preflightContinue: false,
    optionsSuccessStatus: 204,
  });

  console.log('🌐 CORS configurado para orígenes:', corsOrigins === '*' ? 'TODOS (*)' : corsOrigins);
  // ========================================
  
  // Inicializar Firebase Admin SDK
  try {
    // Intentar cargar primero desde el archivo service-account.json en el directorio raíz o en src/config
    const serviceAccountPath = path.join(process.cwd(), 'src', 'config', 'service-account.json');
    const distServiceAccountPath = path.join(process.cwd(), 'dist', 'config', 'service-account.json');
    
    let resolvedPath = null;
    if (fs.existsSync(serviceAccountPath)) {
      resolvedPath = serviceAccountPath;
    } else if (fs.existsSync(distServiceAccountPath)) {
      resolvedPath = distServiceAccountPath;
    }

    if (resolvedPath) {
      admin.initializeApp({
        credential: admin.credential.cert(resolvedPath),
      });
      console.log(`✅ Firebase Admin SDK initialized successfully from ${path.basename(resolvedPath)}`);
    } else {
      // Fallback a variables de entorno
      const projectId = process.env.FIREBASE_PROJECT_ID;
      const rawPrivateKey = process.env.FIREBASE_PRIVATE_KEY;
      const privateKey = rawPrivateKey?.replace(/^"|"$/g, '').replace(/\\n/g, '\n');
      const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;

      // Log para debug (sin mostrar valores sensibles)
      console.log('🔧 Firebase Config Check (Environment):');
      console.log(`   - FIREBASE_PROJECT_ID: ${projectId ? '✓ Set' : '✗ Missing'}`);
      console.log(`   - FIREBASE_PRIVATE_KEY: ${privateKey ? '✓ Set (' + privateKey.substring(0, 30) + '...)' : '✗ Missing'}`);
      console.log(`   - FIREBASE_CLIENT_EMAIL: ${clientEmail ? '✓ Set' : '✗ Missing'}`);

      if (!projectId || !privateKey || !clientEmail) {
        console.warn('⚠️ Firebase credentials not found in environment - push notifications will not work');
        console.warn('   Required: FIREBASE_PROJECT_ID, FIREBASE_PRIVATE_KEY, FIREBASE_CLIENT_EMAIL');
      } else {
        admin.initializeApp({
          credential: admin.credential.cert({
            projectId,
            privateKey,
            clientEmail,
          }),
        });
        console.log('✅ Firebase Admin SDK initialized successfully from environment variables');
      }
    }
  } catch (error) {
    console.error('❌ Error initializing Firebase Admin SDK:', error.message);
    console.warn('⚠️ Push notifications will not work');
  }
  
  app.useGlobalFilters(new AllExceptionsFilter());
  
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      stopAtFirstError: true,
    }),
  );

  // CORS ya configurado arriba con opciones completas

  const port = process.env.PORT ?? 3000;
  await app.listen(port);
  console.log(`🚀 SafeSteps Backend corriendo en puerto ${port}`);
}
bootstrap();
