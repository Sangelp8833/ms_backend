# Especificacion Funcional: ms_backend — Backend API Los Libros de Ivonnet

**Fecha**: 2026-04-15
**Estado**: Aprobada

## Problema

Los Libros de Ivonnet necesita una API backend centralizada que gestione todas las operaciones de la tienda: catálogo de productos, autenticación de usuarios y admins, gestión de órdenes y cálculo de estadísticas de ventas.

## Objetivo

Construir una API REST en Elixir/Phoenix que sirva tanto al ms_storefront (compradores) como al ms_admin (administradores), con separación de rutas y permisos entre roles, persistencia en PostgreSQL, y envío de emails transaccionales.

## Usuarios

- **Comprador (role: `user`)**: puede ver catálogo, registrarse, hacer login, crear órdenes y consultar sus pedidos.
- **Administrador (role: `admin`)**: puede gestionar productos, categorías, actualizar estados de órdenes y consultar estadísticas.
- **Anónimo**: puede ver catálogo y consultar tracking de un pedido por código.

---

## Historias de Usuario

### HU-1: Autenticación de compradores
**Como** comprador, **quiero** registrarme e iniciar sesión, **para** poder comprar y hacer seguimiento de mis pedidos.

**Criterios de aceptación:**
- [ ] Registro: email único, contraseña hasheada (bcrypt), nombre, dirección
- [ ] Login: devuelve JWT con claims: `sub` (user_id), `role` ("user"), `exp` (24h)
- [ ] Si el email ya existe, devuelve 422 con mensaje claro

### HU-2: Autenticación de administradores
**Como** administrador, **quiero** iniciar sesión en un endpoint separado, **para** obtener un token con rol `admin`.

**Criterios de aceptación:**
- [ ] Endpoint exclusivo: POST `/api/auth/admin/login`
- [ ] Solo usuarios con `role = "admin"` en la BD pueden usar este endpoint
- [ ] Usuario regular que intenta por este endpoint recibe 403

### HU-3: Catálogo de productos público
**Como** visitante o comprador, **quiero** ver los productos disponibles filtrados por categoría, **para** encontrar lo que quiero comprar.

**Criterios de aceptación:**
- [ ] Solo productos activos (sin `deleted_at`) aparecen en el catálogo público
- [ ] Filtro por `category_id` vía query param
- [ ] Respuesta paginada: `page`, `per_page`, `total` en meta
- [ ] Cada producto incluye su `type` (standard/sponsored) y `sponsor_info` si aplica

### HU-4: CRUD de productos (admin)
**Como** administrador, **quiero** gestionar el catálogo completo de productos, **para** mantenerlo actualizado.

**Criterios de aceptación:**
- [ ] Crear producto con múltiples imágenes (array de URLs o upload multipart)
- [ ] Editar producto (actualiza campos y puede reemplazar imágenes)
- [ ] Soft delete: setea `deleted_at`, no borra el registro
- [ ] El endpoint de lista admin incluye productos eliminados si se pide `include_deleted=true`
- [ ] Validaciones: nombre requerido, precio > 0, categoría debe existir

### HU-5: Gestión de categorías (admin)
**Como** administrador, **quiero** crear y gestionar categorías, **para** organizar el catálogo.

**Criterios de aceptación:**
- [ ] CRUD completo de categorías
- [ ] Slug único y auto-generado si no se provee
- [ ] Eliminar categoría rechazado con 422 si tiene productos activos asociados

### HU-6: Crear una orden (comprador autenticado)
**Como** comprador autenticado, **quiero** crear una orden con los productos de mi carrito, **para** formalizar mi compra.

**Criterios de aceptación:**
- [ ] Recibe array de `{product_id, quantity}` + `address` + `payment_method`
- [ ] Valida que todos los productos existen y están activos
- [ ] Calcula el total sumando `price * quantity` de cada item (precio snapshoteado al momento de la orden)
- [ ] Genera un `tracking_code` único (ej: `LIV-A3F9`)
- [ ] Estado inicial: `received`
- [ ] Envía email de confirmación al comprador con el tracking code vía Resend

### HU-7: Tracking de pedido (público)
**Como** visitante o comprador, **quiero** consultar el estado de un pedido con su código, **para** saber en qué etapa está.

**Criterios de aceptación:**
- [ ] GET `/api/storefront/orders/:code` sin autenticación
- [ ] Devuelve `tracking_code`, `status`, `created_at`, `updated_at`
- [ ] Si el código no existe → 404

### HU-8: Actualizar estado de orden (admin)
**Como** administrador, **quiero** avanzar el estado de una orden, **para** mantener al comprador informado.

**Criterios de aceptación:**
- [ ] PUT `/api/admin/orders/:id/status`
- [ ] Solo avanza en orden: `received → preparing → shipped → delivered`
- [ ] Si el estado enviado no es el siguiente válido → 422
- [ ] Si ya está `delivered` → 422 "La orden ya fue entregada"

### HU-9: Estadísticas de ventas (admin)
**Como** administrador, **quiero** consultar métricas de ventas, **para** evaluar el rendimiento del negocio.

**Criterios de aceptación:**
- [ ] Ventas por mes (total en dinero + cantidad de órdenes) filtrado por rango de fechas
- [ ] Top productos más vendidos (unidades + revenue), incluyendo soft-deleted
- [ ] Métricas del mes actual: total ventas, órdenes activas, productos activos, órdenes pendientes

---

## Alcance

### Incluido
- Auth JWT para compradores y admins
- Catálogo público de productos (read-only)
- CRUD de productos y categorías (admin)
- Creación y tracking de órdenes (comprador)
- Actualización de estado de órdenes (admin)
- Historial de órdenes con filtros (admin)
- Estadísticas de ventas (admin)
- Email de confirmación de orden (Resend)

### Excluido
- Integración con pasarela de pago real (primer MVP usa `payment_method: "transfer"`)
- Gestión de stock en tiempo real (campo `in_stock` se actualiza manualmente)
- Notificaciones WebSocket / tiempo real
- Carga de archivos/imágenes directa al backend (se reciben como URLs en el MVP)
- Multi-tenancy
- Rate limiting (iteración posterior)

## Reglas de Negocio

1. **Precio snapshoteado**: al crear una orden, el precio del producto se copia en el `order_item`. Si el precio del producto cambia después, la orden mantiene el precio original.
2. **Tracking code**: formato `LIV-XXXX` donde XXXX es alfanumérico aleatorio en mayúsculas (4-6 chars). Debe ser único en la base de datos.
3. **Soft delete**: `deleted_at` en la tabla `products`. Los productos eliminados no aparecen en el catálogo público pero sí en reportes admin.
4. **Avance de estado lineal**: el campo `status` solo puede avanzar: `received → preparing → shipped → delivered`. El backend rechaza cualquier otro movimiento.
5. **Email de confirmación**: se envía tras crear la orden. Si Resend falla, la orden igual se crea (no es bloqueante).
6. **Categorías con productos activos**: no se pueden eliminar.

## Dependencias

- **PostgreSQL**: base de datos principal
- **Resend**: envío de email transaccional (API key en config)
- **Joken**: generación/verificación de JWT
- **bcrypt** (via Comeonin/Bcrypt o similar): hasheo de contraseñas
