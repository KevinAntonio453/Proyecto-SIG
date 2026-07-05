-- ⚠️ NOTA: Este archivo es para PostgreSQL, no MSSQL
-- Si ves errores en VS Code, son falsos positivos del linter de MSSQL
-- La migración ya fue ejecutada exitosamente en PostgreSQL

-- Migración: Agregar campos de tracking de zonas seguras a tabla 'users' (hijos)
-- Fecha: 2025-12-07
-- Descripción: Agrega estadoZona y zonaActualId para trackear entrada/salida de zonas
-- Estado: ✅ EJECUTADA EXITOSAMENTE

-- Agregar columna estadoZona (DENTRO o FUERA)
ALTER TABLE "users" 
ADD COLUMN IF NOT EXISTS "estadoZona" VARCHAR(10) DEFAULT 'FUERA';

-- Agregar columna zonaActualId (referencia a zona actual)
ALTER TABLE "users" 
ADD COLUMN IF NOT EXISTS "zonaActualId" INTEGER;

-- Actualizar registros existentes al estado por defecto
UPDATE "users" 
SET "estadoZona" = 'FUERA', "zonaActualId" = NULL
WHERE "estadoZona" IS NULL;

-- Comentarios explicativos
COMMENT ON COLUMN "users"."estadoZona" IS 'Estado actual del hijo respecto a zonas seguras: DENTRO o FUERA';
COMMENT ON COLUMN "users"."zonaActualId" IS 'ID de la zona segura donde está actualmente (NULL si está FUERA)';
