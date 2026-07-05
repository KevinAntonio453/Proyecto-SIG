-- ⚠️ NOTA: Este archivo es para PostgreSQL, no MSSQL
-- Si ves errores en VS Code, son falsos positivos del linter de MSSQL

-- Migración: Agregar campo fueOffline a tabla 'registros'
-- Fecha: 2025-12-07
-- Descripción: Permite identificar registros de ubicación guardados offline vs online
-- Estado: PENDIENTE DE EJECUTAR

-- Agregar columna fueOffline (indica si el registro se hizo sin conexión)
ALTER TABLE "registros" 
ADD COLUMN IF NOT EXISTS "fueOffline" BOOLEAN DEFAULT false;

-- Actualizar registros existentes al valor por defecto
UPDATE "registros" 
SET "fueOffline" = false
WHERE "fueOffline" IS NULL;

-- Comentario explicativo
COMMENT ON COLUMN "registros"."fueOffline" IS 'Indica si el registro se guardó sin conexión a internet (true) o con conexión (false)';
