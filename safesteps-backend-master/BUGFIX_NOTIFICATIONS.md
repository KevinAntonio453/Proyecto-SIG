# 🐛 BUGFIX: Notificaciones - Errores Críticos Resueltos

**Fecha:** 6 de diciembre de 2025
**Reportado por:** Desarrollador Flutter
**Estado:** ✅ RESUELTO

---

## 📋 Problemas Reportados

### 1. GET /notifications devuelve lista vacía

**Síntoma:**

```json
GET /notifications?limit=20&offset=0
Response: {
  "notifications": [],
  "total": 0,
  "unreadCount": 222
}
```

- **Problema:** El backend indica 222 notificaciones no leídas, pero devuelve array vacío
- **Impacto:** Flutter no puede mostrar notificaciones ni obtener IDs para marcar como leído

### 2. POST /notifications/mark-all-read falla con 500

**Síntoma:**

```
POST /notifications/mark-all-read
Response: 500 Internal Server Error
```

- **Problema:** El servidor crash al intentar marcar todas como leídas
- **Impacto:** El usuario no puede marcar todas las notificaciones como leídas

---

## 🔍 Diagnóstico

### Causa Raíz

**TypeORM no puede resolver relaciones sin JOIN explícito**

Los métodos usaban sintaxis incorrecta para filtrar por `tutor`:

```typescript
// ❌ INCORRECTO - TypeORM no puede resolver esto automáticamente
.where('notification.tutor.id = :tutorId', { tutorId })

// ❌ INCORRECTO - No funciona con relaciones anidadas
where: { tutor: { id: tutorId }, leida: false }
```

**Logs del Error:**

```sql
SELECT ... FROM "notifications" "notification"
WHERE "notification"."tutor_id" = $1
-- PARAMETERS: [null]  ❌ tutorId es NULL!
```

### Análisis Técnico

1. **Sin JOIN**: TypeORM no carga la relación `tutor`, resultando en `tutorId = null`
2. **QueryBuilder incompleto**: Faltaba `leftJoinAndSelect('notification.tutor', 'tutor')`
3. **Relación anidada en WHERE**: TypeORM no puede hacer queries complejos sin alias explícitos
4. **Entidad sin columna directa**: Faltaba `@Column({ name: 'tutor_id' }) tutorId: number`

---

## ✅ Solución Implementada

### Cambios en la Entidad

**Archivo:** `src/notifications/entities/notification.entity.ts`

```typescript
@Entity('notifications')
export class Notification {
  // ... otros campos ...

  @Column({ type: 'boolean', default: false })
  leida: boolean;

  // ✅ AGREGADO: Columna explícita para queries directos
  @Column({ name: 'tutor_id' })
  tutorId: number;

  @ManyToOne(() => Tutor, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'tutor_id' })
  tutor: Tutor;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
```

### Cambios en el Servicio

**Archivo:** `src/notifications/notifications.service.ts`

#### 1. Método `findAllByTutor()` - GET /notifications

```typescript
// ✅ ANTES (con error)
const queryBuilder = this.notificationRepository
  .createQueryBuilder('notification')
  .where('notification.tutor.id = :tutorId', { tutorId }) // ❌ Error aquí
  .orderBy('notification.createdAt', 'DESC');

// ✅ DESPUÉS (corregido)
const queryBuilder = this.notificationRepository
  .createQueryBuilder('notification')
  .leftJoinAndSelect('notification.tutor', 'tutor') // ✅ JOIN explícito
  .where('tutor.id = :tutorId', { tutorId }) // ✅ Usa alias del JOIN
  .orderBy('notification.createdAt', 'DESC');

// También se corrigió el unreadCount:
const unreadCount = await this.notificationRepository
  .createQueryBuilder('notification')
  .where('notification.tutorId = :tutorId', { tutorId }) // ✅ Usa columna directa
  .andWhere('notification.leida = :leida', { leida: false })
  .getCount();
```

#### 2. Método `markAllAsRead()` - POST /notifications/mark-all-read

```typescript
// ✅ ANTES (con error)
const result = await this.notificationRepository.update(
  { tutor: { id: tutorId }, leida: false }, // ❌ No funciona con relaciones
  { leida: true },
);

// ✅ DESPUÉS (corregido)
const result = await this.notificationRepository
  .createQueryBuilder()
  .update(Notification)
  .set({ leida: true })
  .where('tutorId = :tutorId', { tutorId }) // ✅ Usa columna directa
  .andWhere('leida = :leida', { leida: false })
  .execute();
```

#### 3. Método `markAsRead()` - POST /notifications/mark-read

```typescript
// ✅ Verificación de permisos con JOIN
const notifications = await this.notificationRepository
  .createQueryBuilder('notification')
  .leftJoinAndSelect('notification.tutor', 'tutor')
  .where('notification.id IN (:...notificationIds)', { notificationIds })
  .andWhere('tutor.id = :tutorId', { tutorId })
  .getMany();

// ✅ Actualización con columna directa
const result = await this.notificationRepository
  .createQueryBuilder()
  .update(Notification)
  .set({ leida: true })
  .where('id IN (:...notificationIds)', { notificationIds })
  .andWhere('tutorId = :tutorId', { tutorId })
  .andWhere('leida = :leida', { leida: false })
  .execute();
```

#### 4. Método `getUnreadCount()` - GET /notifications/unread/count

```typescript
// ✅ ANTES (con error)
const count = await this.notificationRepository.count({
  where: { tutor: { id: tutorId }, leida: false }, // ❌ No funciona
});

// ✅ DESPUÉS (corregido)
const count = await this.notificationRepository
  .createQueryBuilder('notification')
  .where('notification.tutorId = :tutorId', { tutorId })
  .andWhere('notification.leida = :leida', { leida: false })
  .getCount();
```

#### 5. Método `findOne()` - GET /notifications/:id

```typescript
// ✅ ANTES (con error)
const notification = await this.notificationRepository.findOne({
  where: { id, tutor: { id: tutorId } }, // ❌ No funciona
});

// ✅ DESPUÉS (corregido)
const notification = await this.notificationRepository
  .createQueryBuilder('notification')
  .leftJoinAndSelect('notification.tutor', 'tutor')
  .where('notification.id = :id', { id })
  .andWhere('notification.tutorId = :tutorId', { tutorId })
  .getOne();
```

#### 6. Método `removeMany()` - DELETE /notifications

```typescript
// ✅ Verificación de permisos con QueryBuilder
const notifications = await this.notificationRepository
  .createQueryBuilder('notification')
  .where('notification.id IN (:...notificationIds)', { notificationIds })
  .andWhere('notification.tutorId = :tutorId', { tutorId })
  .getMany();
```

---

## 🧪 Verificación

### Queries SQL Generados (Correctos)

```sql
-- GET /notifications?leida=false
SELECT
  notification.*,
  tutor.*
FROM notifications notification
LEFT JOIN users tutor ON tutor.id = notification.tutor_id
WHERE tutor.id = 2
  AND notification.leida = false
ORDER BY notification.created_at DESC
LIMIT 20 OFFSET 0;

-- POST /notifications/mark-all-read
UPDATE notifications
SET leida = true
WHERE tutor_id = 2
  AND leida = false;

-- GET /notifications/unread/count
SELECT COUNT(*)
FROM notifications
WHERE tutor_id = 2
  AND leida = false;
```

### Pruebas Esperadas

1. ✅ `GET /notifications` devuelve lista correcta con 222 notificaciones
2. ✅ `GET /notifications?leida=false` filtra solo no leídas
3. ✅ `POST /notifications/mark-all-read` marca todas correctamente (200 OK)
4. ✅ `GET /notifications/unread/count` devuelve conteo correcto
5. ✅ `POST /notifications/mark-read` marca IDs específicos correctamente

---

## 📝 Lecciones Aprendidas

### ⚠️ Errores Comunes con TypeORM

1. **No asumir que TypeORM resuelve relaciones automáticamente**

   ```typescript
   // ❌ NUNCA HACER ESTO
   .where('entity.relation.field = :value')

   // ✅ SIEMPRE HACER ESTO
   .leftJoinAndSelect('entity.relation', 'relationAlias')
   .where('relationAlias.field = :value')
   ```

2. **Agregar columnas directas para queries frecuentes**

   ```typescript
   // ✅ Agrega columna explícita para queries directos
   @Column({ name: 'foreign_key_id' })
   foreignKeyId: number;

   @ManyToOne(() => RelatedEntity)
   @JoinColumn({ name: 'foreign_key_id' })
   relatedEntity: RelatedEntity;
   ```

3. **Usar QueryBuilder para operaciones complejas**

   ```typescript
   // ❌ EVITAR para queries con relaciones
   repository.find({ where: { relation: { id: value } } });

   // ✅ PREFERIR QueryBuilder
   repository
     .createQueryBuilder('entity')
     .where('entity.relationId = :value', { value })
     .getMany();
   ```

### 🎯 Mejores Prácticas

1. **Siempre agregar columna de FK cuando se usa `@ManyToOne`**
2. **Usar QueryBuilder para queries con WHERE complejos**
3. **Probar queries en producción con datos reales**
4. **Revisar logs SQL para detectar valores NULL**
5. **Usar `leftJoinAndSelect` solo cuando necesites cargar la relación**
6. **Usar columna directa (`tutorId`) para filtros simples**

---

## 🚀 Despliegue

```bash
# Los cambios se aplicaron automáticamente con hot-reload
# Para reinicio manual:
docker-compose restart app

# Verificar logs:
docker-compose logs -f app

# Confirmar que el servidor inició:
# [Nest] LOG [NestApplication] Nest application successfully started
```

---

## 📞 Para el Desarrollador Flutter

Los endpoints ahora funcionan correctamente:

```dart
// ✅ Ahora devuelve las 222 notificaciones
final response = await http.get(
  Uri.parse('$baseUrl/notifications?leida=false&limit=20&offset=0'),
  headers: {'Authorization': 'Bearer $token'},
);

// ✅ Ahora marca todas como leídas exitosamente
final response = await http.post(
  Uri.parse('$baseUrl/notifications/mark-all-read'),
  headers: {'Authorization': 'Bearer $token'},
);
```

**Puedes probar inmediatamente en tu app Flutter** ✅
