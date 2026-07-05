# Configuración de Firebase

## Instrucciones para configurar Firebase Admin SDK

1. **Obtener el archivo de credenciales:**
   - Ve a [Firebase Console](https://console.firebase.google.com/)
   - Selecciona tu proyecto: `safesteps-7c38b`
   - Ve a **Project Settings** (⚙️) → **Service Accounts**
   - Click en **Generate New Private Key**
   - Descarga el archivo JSON

2. **Instalar el archivo:**
   - Guarda el archivo descargado como: `src/config/service-account.json`
   - **IMPORTANTE:** Este archivo contiene credenciales privadas y NO debe ser compartido ni subido al repositorio

3. **Estructura esperada del archivo:**

```json
{
  "type": "service_account",
  "project_id": "safesteps-7c38b",
  "private_key_id": "...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-xxxxx@safesteps-7c38b.iam.gserviceaccount.com",
  "client_id": "...",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "..."
}
```

## Verificación

Cuando inicies el backend, deberías ver este mensaje en los logs:

```
✅ Firebase Admin SDK initialized successfully
```

Si no ves este mensaje, verifica que:

- El archivo `service-account.json` existe en `src/config/`
- El archivo tiene el formato JSON correcto
- Los permisos del archivo permiten lectura

## Seguridad

⚠️ **NUNCA** compartas este archivo públicamente ni lo subas a GitHub

- El archivo está protegido en `.gitignore`
- Si el archivo se filtra, revoca las credenciales desde Firebase Console inmediatamente
