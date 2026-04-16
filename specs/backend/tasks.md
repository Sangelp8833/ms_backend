# Tareas: ms_backend — Backend API Los Libros de Ivonnet

**Fecha**: 2026-04-15
**Spec Funcional**: spec-funcional.md
**Spec Técnica**: spec-tecnica.md

## Resumen

- **Total tareas**: 13
- **Progreso**: 0/13 completadas

---

## Tareas

### T1. Setup: dependencias y configuración
**Capa**: config
**Tamaño**: S
**Depende de**: Ninguna

**Qué hacer:**
- [ ] Agregar `{:bcrypt_elixir, "~> 3.0"}` a `mix.exs`
- [ ] Verificar deps existentes: `joken`, `ecto_sql`, `postgrex`, `finch`, `corsica`
- [ ] Actualizar `config/dev.exs`: database `los_libros_de_ivonnet_dev`, usuario y contraseña postgres locales
- [ ] Verificar `config/test.exs`: database `los_libros_de_ivonnet_test`
- [ ] Agregar config `:resend_api_key` y `:resend_from` en `dev.exs`

**Archivos involucrados:**
- `mix.exs`, `config/dev.exs`, `config/test.exs`

**Criterio de completado:** `mix deps.get` sin errores; `mix ecto.create` crea la base de datos.

---

### T2. Migraciones de base de datos
**Capa**: base de datos
**Tamaño**: M
**Depende de**: T1

**Qué hacer:**
- [ ] Crear `priv/repo/migrations/TIMESTAMP_create_users.exs`:
  - `id` UUID PK, `name`, `email` (unique), `password_hash`, `address`, `role` (default: "user"), timestamps
- [ ] Crear `priv/repo/migrations/TIMESTAMP_create_categories.exs`:
  - `id` UUID PK, `name`, `slug` (unique), timestamps
- [ ] Crear `priv/repo/migrations/TIMESTAMP_create_products.exs`:
  - `id` UUID PK, `name`, `description`, `price` (integer), `image_urls` (array text), `type`, `sponsor_name`, `sponsor_logo_url`, `sponsor_tagline`, `in_stock`, `deleted_at`, FK `category_id`, timestamps
  - Índices: `category_id`, `deleted_at`
- [ ] Crear `priv/repo/migrations/TIMESTAMP_create_orders.exs`:
  - `id` UUID PK, `tracking_code` (unique), FK `user_id`, `status` (default: "received"), `address`, `payment_method`, `total`, timestamps
  - Índices: `user_id`, `tracking_code`, `status`, `inserted_at`
- [ ] Crear `priv/repo/migrations/TIMESTAMP_create_order_items.exs`:
  - `id` UUID PK, FK `order_id` (on delete cascade), FK `product_id`, `name`, `image_url`, `price`, `quantity`, `inserted_at`

**Archivos involucrados:**
- `priv/repo/migrations/*.exs`

**Criterio de completado:** `mix ecto.migrate` ejecuta sin errores; `\dt` en psql muestra las 5 tablas.

---

### T3. Schema y Context: Accounts (users)
**Capa**: modelo + context
**Tamaño**: M
**Depende de**: T2

**Qué hacer:**
- [ ] Crear `lib/ms_backend/accounts/user.ex`:
  - Schema Ecto con campos: `name`, `email`, `password` (virtual), `password_hash`, `address`, `role`
  - `changeset/2` con validaciones: email único, password ≥ 8 chars, hasheo con `Bcrypt.hash_pwd_salt/1`
- [ ] Crear `lib/ms_backend/accounts/accounts.ex`:
  - `register_user(attrs)`: crea usuario con rol "user"
  - `authenticate_user(email, password)`: busca por email, verifica con `Bcrypt.verify_pass/2`, retorna `{:ok, user}` o `{:error, :invalid_credentials}`
  - `authenticate_admin(email, password)`: igual pero verifica `role == "admin"`; si usuario existe pero no es admin → `{:error, :forbidden}`
  - `get_user(id)`: busca por UUID

**Archivos involucrados:**
- `lib/ms_backend/accounts/user.ex`, `lib/ms_backend/accounts/accounts.ex`

**Criterio de completado:** Tests unitarios pasan: crear usuario, login válido, login con contraseña incorrecta, login con usuario no-admin en endpoint admin.

---

### T4. Auth controller y JWT
**Capa**: controller
**Tamaño**: M
**Depende de**: T3

**Qué hacer:**
- [ ] Completar `lib/ms_backend/auth.ex`:
  - `generate_token(user_id, role)`: JWT con claims `sub`, `role`, `iat`, `exp` (24h), firmado con secret de config
  - `verify_token(token)`: verifica firma y expiración; retorna `{:ok, claims}` o `{:error, reason}`
- [ ] Crear `lib/ms_backend_web/controllers/auth_controller.ex`:
  - `register/2`: POST `/api/auth/register` → `Accounts.register_user` → devuelve token + user
  - `login/2`: POST `/api/auth/login` → `Accounts.authenticate_user` → devuelve token + user
  - `admin_login/2`: POST `/api/auth/admin/login` → `Accounts.authenticate_admin` → 200 o 403
  - `logout/2`: DELETE `/api/auth/logout` → 200 OK (el token se invalida en el cliente)
  - `me/2`: GET `/api/auth/me` → devuelve `conn.assigns.current_user_id` info
- [ ] Crear `lib/ms_backend_web/views/auth_view.ex`: funciones de renderizado JSON
- [ ] Completar `lib/ms_backend_web/plugs/require_auth.ex` y `require_admin.ex`

**Archivos involucrados:**
- `lib/ms_backend/auth.ex`, `lib/ms_backend_web/controllers/auth_controller.ex`, `lib/ms_backend_web/views/auth_view.ex`, plugs

**Criterio de completado:** Flujo completo: registro → login → token válido → llamada autenticada funciona; admin_login rechaza usuarios regulares con 403.

---

### T5. Schema y Context: Catalog (categorías)
**Capa**: modelo + context
**Tamaño**: S
**Depende de**: T2

**Qué hacer:**
- [ ] Crear `lib/ms_backend/catalog/category.ex`:
  - Schema: `name`, `slug` (unique)
  - `changeset/2` con auto-generación de slug desde nombre si no se provee (`String.downcase |> String.replace(~r/\s+/, "-")`)
- [ ] Crear `lib/ms_backend/catalog/catalog.ex` (solo categorías por ahora):
  - `list_categories()`: SELECT * FROM categories ORDER BY name
  - `create_category(attrs)`: insert + unique constraint handling
  - `update_category(category, attrs)`: update
  - `delete_category(category)`: verifica no tiene productos activos → DELETE o `{:error, :has_products}`

**Archivos involucrados:**
- `lib/ms_backend/catalog/category.ex`, `lib/ms_backend/catalog/catalog.ex`

**Criterio de completado:** CRUD de categorías funciona; eliminar con productos activos retorna error correcto.

---

### T6. Schema y Context: Catalog (productos)
**Capa**: modelo + context
**Tamaño**: M
**Depende de**: T5

**Qué hacer:**
- [ ] Crear `lib/ms_backend/catalog/product.ex`:
  - Schema con todos los campos (ver spec técnica)
  - `changeset/2`: validar `name`, `price > 0`, `category_id` existe (assoc_constraint)
  - Si `type == "sponsored"`: validar que `sponsor_name` no sea nulo
- [ ] Ampliar `lib/ms_backend/catalog/catalog.ex` con productos:
  - `list_products(opts)`: filtra por `category_id` (opcional), excluye `deleted_at IS NOT NULL` para catálogo público; incluye eliminados para admin; pagina con `limit/offset`
  - `get_product(id)`: retorna producto o `nil`
  - `create_product(attrs)`: insert
  - `update_product(product, attrs)`: update
  - `soft_delete_product(product)`: `Ecto.Changeset.change(product, deleted_at: DateTime.utc_now()) |> Repo.update()`

**Archivos involucrados:**
- `lib/ms_backend/catalog/product.ex`, `lib/ms_backend/catalog/catalog.ex`

**Criterio de completado:** Crear producto con tipo sponsored sin sponsor_name falla la validación; soft_delete setea deleted_at; list_products sin `include_deleted` no retorna soft-deleted.

---

### T7. Product y Category controllers
**Capa**: controller
**Tamaño**: M
**Depende de**: T6, T4

**Qué hacer:**
- [ ] Crear `lib/ms_backend_web/controllers/product_controller.ex`:
  - `index/2` (storefront público): lista productos activos con paginación
  - `show/2` (storefront público): detalle de un producto activo
  - `admin_index/2` (admin): lista todos incluyendo soft-deleted
  - `create/2` (admin): POST con campos del producto
  - `update/2` (admin): PUT actualización
  - `delete/2` (admin): soft delete
- [ ] Crear `lib/ms_backend_web/controllers/category_controller.ex`:
  - `index/2` (público): lista categorías
  - `create/2`, `update/2`, `delete/2` (admin)
- [ ] Crear views correspondientes con `render("product.json", ...)` que serializa el producto incluyendo `sponsor_info` solo si type es sponsored

**Archivos involucrados:**
- `lib/ms_backend_web/controllers/product_controller.ex`, `lib/ms_backend_web/controllers/category_controller.ex`, views

**Criterio de completado:** GET /api/storefront/products devuelve solo activos; GET /api/admin/products devuelve todos; DELETE hace soft-delete y el producto desaparece del catálogo público.

---

### T8. Schema y Context: Orders
**Capa**: modelo + context
**Tamaño**: L
**Depende de**: T6, T3

**Qué hacer:**
- [ ] Crear `lib/ms_backend/orders/order_item.ex`: schema con `order_id`, `product_id`, `name`, `image_url`, `price`, `quantity`
- [ ] Crear `lib/ms_backend/orders/order.ex`:
  - Schema con `tracking_code`, `user_id`, `status`, `address`, `payment_method`, `total`, `has_many :items`
  - Constante `@status_transitions` con el mapa de transiciones válidas
- [ ] Crear `lib/ms_backend/orders/orders.ex`:
  - `create_order(user, attrs)`:
    1. Validar que todos los `product_id` existen y están activos
    2. Calcular total: `SUM(product.price * quantity)` de cada item
    3. Generar tracking code único (`LIV-XXXXXX`)
    4. Insertar orden + items en una transacción (`Repo.transaction`)
    5. Llamar `MsBackend.Mailer.send_order_confirmation/2` (async, no bloquea)
    6. Retornar `{:ok, order_with_items}`
  - `get_by_tracking_code(code)`: para tracking público
  - `list_orders_for_user(user_id)`: mis órdenes
  - `list_all_orders(opts)`: admin, con filtros: status, from, to, query (tracking o email)
  - `update_status(order, new_status)`: valida transición lineal, actualiza
  - `get_order_with_items(id)`: preload items

**Archivos involucrados:**
- `lib/ms_backend/orders/order.ex`, `lib/ms_backend/orders/order_item.ex`, `lib/ms_backend/orders/orders.ex`

**Criterio de completado:** Crear orden en transacción: si falla la inserción de un item, la orden no se crea; tracking code único generado; update_status rechaza transiciones inválidas.

---

### T9. Order controller
**Capa**: controller
**Tamaño**: M
**Depende de**: T8, T4

**Qué hacer:**
- [ ] Crear `lib/ms_backend_web/controllers/order_controller.ex`:
  - `create/2` (auth user): POST `/api/storefront/orders`
  - `my_orders/2` (auth user): GET `/api/storefront/orders`
  - `track/2` (público): GET `/api/storefront/orders/:code`
  - `admin_index/2` (admin): GET `/api/admin/orders` con filtros query
  - `update_status/2` (admin): PUT `/api/admin/orders/:id/status`
- [ ] Crear `lib/ms_backend_web/views/order_view.ex`: serializar orden con items, usuario (nombre+email)

**Archivos involucrados:**
- `lib/ms_backend_web/controllers/order_controller.ex`, `lib/ms_backend_web/views/order_view.ex`

**Criterio de completado:** Crear orden válida devuelve 201 con tracking code; tracking público funciona sin auth; update_status con transición inválida devuelve 422.

---

### T10. Mailer (email de confirmación)
**Capa**: servicio
**Tamaño**: S
**Depende de**: T1

**Qué hacer:**
- [ ] Crear `lib/ms_backend/mailer.ex`:
  - `send_order_confirmation(email, tracking_code)`:
    - Construye payload JSON para Resend API
    - POST a `https://api.resend.com/emails` via Finch
    - HTML básico con el tracking code
    - Ejecuta en `Task.start` para no bloquear
    - Si falla: `Logger.error("Email send failed: #{inspect(reason)}")`
  - En `config/test.exs`: `config :ms_backend, mailer_enabled: false` para no enviar en tests

**Archivos involucrados:**
- `lib/ms_backend/mailer.ex`, `config/dev.exs`, `config/test.exs`

**Criterio de completado:** En desarrollo, crear una orden envía el email (verificable en los logs de Resend); en test, no se llama a la API de Resend.

---

### T11. Stats controller
**Capa**: controller
**Tamaño**: M
**Depende de**: T9

**Qué hacer:**
- [ ] Ampliar `lib/ms_backend/orders/orders.ex` con funciones de stats:
  - `sales_by_month(from, to)`: query SQL raw o Ecto con `fragment`; agrupa por mes
  - `top_products(from, to, limit)`: JOIN con order_items, agrupa por producto, incluye soft-deleted
  - `monthly_stats()`: conteos del mes actual (ventas, órdenes activas, productos activos, pendientes)
- [ ] Crear `lib/ms_backend_web/controllers/stats_controller.ex`:
  - `sales/2`: GET `/api/admin/stats/sales?from=...&to=...`
  - `top_products/2`: GET `/api/admin/stats/products?from=...&to=...&limit=10`
  - `monthly/2`: GET `/api/admin/stats/monthly`
- [ ] Crear `lib/ms_backend_web/views/stats_view.ex`

**Archivos involucrados:**
- `lib/ms_backend/orders/orders.ex`, `lib/ms_backend_web/controllers/stats_controller.ex`, `lib/ms_backend_web/views/stats_view.ex`

**Criterio de completado:** Las 3 rutas de stats devuelven datos correctos; top_products incluye productos soft-deleted con sus ventas históricas.

---

### T12. Seed data para desarrollo
**Capa**: datos
**Tamaño**: S
**Depende de**: T7, T9

**Qué hacer:**
- [ ] Crear `priv/repo/seeds.exs`:
  - 1 usuario admin (email: `admin@loslibrosdivonnet.com`, password: `admin1234`)
  - 1 usuario regular de prueba
  - 3-4 categorías: Kits Temáticos, Libretas, Mocks, Novedades
  - 6-8 productos variados (algunos sponsored, algunos estándar)
  - 2-3 órdenes en diferentes estados
- [ ] Agregar alias en `mix.exs` o documentar cómo ejecutar: `mix run priv/repo/seeds.exs`

**Archivos involucrados:**
- `priv/repo/seeds.exs`

**Criterio de completado:** `mix run priv/repo/seeds.exs` crea los datos sin error; login con el admin de seed funciona.

---

### T13. Testing básico y smoke test
**Capa**: tests
**Tamaño**: M
**Depende de**: T12

**Qué hacer:**
- [ ] Tests de context en `test/ms_backend/accounts_test.exs`: register, login válido, login inválido, admin_login
- [ ] Tests de context en `test/ms_backend/catalog_test.exs`: CRUD categorías, CRUD productos, soft delete
- [ ] Tests de context en `test/ms_backend/orders_test.exs`: create_order, tracking, update_status válido e inválido
- [ ] Smoke test de endpoints en `test/ms_backend_web/controllers/`:
  - POST /auth/register → 201
  - POST /auth/login → 200
  - GET /storefront/products → 200
  - POST /storefront/orders (sin auth) → 401
  - GET /admin/products (sin auth) → 401
  - GET /admin/products (con token user) → 403

**Archivos involucrados:**
- `test/ms_backend/*.exs`, `test/ms_backend_web/controllers/*.exs`

**Criterio de completado:** `mix test` pasa; los permisos por rol están correctamente validados en los smoke tests.

---

## Orden Sugerido de Implementación

1. **T1** — Setup deps y config
2. **T2** — Migraciones (base para todo)
3. **T3** — Accounts: users + context
4. **T4** — Auth controller + JWT + plugs
5. **T5** — Catalog: categorías
6. **T6** — Catalog: productos
7. **T7** — Product + Category controllers
8. **T8** — Orders: schemas + context (el más complejo)
9. **T9** — Order controller
10. **T10** — Mailer (puede hacerse en paralelo con T8)
11. **T11** — Stats controller
12. **T12** — Seeds dev
13. **T13** — Tests

## Notas

- Usar `mix phx.gen.migration` para generar las migraciones con timestamps automáticos.
- En el MVP, las imágenes de productos son URLs externas (string); no se implementa S3 en esta fase.
- Los precios están en **pesos colombianos enteros** (e.g. 85000 = $85.000 COP). No usar `float`.
- Para las queries de estadísticas, usar `Ecto.Query` con `fragment/1` para las funciones de fecha de PostgreSQL.
