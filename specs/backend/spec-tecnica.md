# Especificacion Técnica: ms_backend — Backend API Los Libros de Ivonnet

**Fecha**: 2026-04-15
**Estado**: Aprobada
**Base**: spec-funcional.md

---

## Stack

- **Lenguaje**: Elixir 1.14+
- **Framework**: Phoenix 1.7 (modo API, sin LiveView)
- **Base de datos**: PostgreSQL (via Ecto 3.10)
- **Auth**: Joken 2.6 (JWT HS256)
- **Email**: Finch + llamadas directas a Resend API
- **Passwords**: `bcrypt_elixir` (~> 3.0)
- **CORS**: Corsica 2.0 (permite orígenes de storefront y admin)

---

## Arquitectura

```
lib/
├── ms_backend.ex
├── ms_backend/
│   ├── application.ex
│   ├── repo.ex
│   ├── auth.ex                    # JWT helpers
│   ├── mailer.ex                  # Envío de emails via Resend
│   ├── accounts/
│   │   ├── user.ex                # Schema Ecto
│   │   └── accounts.ex            # Context: register, login, get_user
│   ├── catalog/
│   │   ├── product.ex             # Schema Ecto
│   │   ├── category.ex            # Schema Ecto
│   │   └── catalog.ex             # Context: list, get, create, update, delete
│   └── orders/
│       ├── order.ex               # Schema Ecto
│       ├── order_item.ex          # Schema Ecto
│       └── orders.ex              # Context: create, get, update_status, stats
└── ms_backend_web/
    ├── endpoint.ex
    ├── router.ex
    ├── gettext.ex
    ├── telemetry.ex
    ├── plugs/
    │   ├── require_auth.ex
    │   └── require_admin.ex
    ├── controllers/
    │   ├── auth_controller.ex
    │   ├── product_controller.ex
    │   ├── category_controller.ex
    │   ├── order_controller.ex
    │   └── stats_controller.ex
    └── views/
        ├── error_view.ex
        ├── auth_view.ex
        ├── product_view.ex
        ├── category_view.ex
        ├── order_view.ex
        └── stats_view.ex

priv/
└── repo/
    └── migrations/
        ├── 001_create_users.exs
        ├── 002_create_categories.exs
        ├── 003_create_products.exs
        ├── 004_create_orders.exs
        └── 005_create_order_items.exs
```

---

## Modelo de Datos (PostgreSQL)

### Tabla: `users`
```sql
CREATE TABLE users (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        VARCHAR(255) NOT NULL,
  email       VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  address     TEXT,
  role        VARCHAR(20) NOT NULL DEFAULT 'user',  -- 'user' | 'admin'
  inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMP NOT NULL DEFAULT NOW()
);
CREATE INDEX ON users(email);
```

### Tabla: `categories`
```sql
CREATE TABLE categories (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        VARCHAR(255) NOT NULL,
  slug        VARCHAR(255) NOT NULL UNIQUE,
  inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMP NOT NULL DEFAULT NOW()
);
```

### Tabla: `products`
```sql
CREATE TABLE products (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            VARCHAR(255) NOT NULL,
  description     TEXT,
  price           INTEGER NOT NULL,           -- en centavos/pesos enteros
  image_urls      TEXT[] NOT NULL DEFAULT '{}',
  category_id     UUID NOT NULL REFERENCES categories(id),
  type            VARCHAR(20) NOT NULL DEFAULT 'standard',  -- 'standard' | 'sponsored'
  sponsor_name    VARCHAR(255),
  sponsor_logo_url TEXT,
  sponsor_tagline  VARCHAR(500),
  in_stock        BOOLEAN NOT NULL DEFAULT TRUE,
  deleted_at      TIMESTAMP,                  -- NULL = activo
  inserted_at     TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMP NOT NULL DEFAULT NOW()
);
CREATE INDEX ON products(category_id);
CREATE INDEX ON products(deleted_at);
```

### Tabla: `orders`
```sql
CREATE TABLE orders (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tracking_code  VARCHAR(20) NOT NULL UNIQUE,
  user_id        UUID NOT NULL REFERENCES users(id),
  status         VARCHAR(20) NOT NULL DEFAULT 'received',
  address        TEXT NOT NULL,
  payment_method VARCHAR(50) NOT NULL DEFAULT 'transfer',
  total          INTEGER NOT NULL,            -- suma calculada en el backend
  inserted_at    TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMP NOT NULL DEFAULT NOW()
);
CREATE INDEX ON orders(user_id);
CREATE INDEX ON orders(tracking_code);
CREATE INDEX ON orders(status);
CREATE INDEX ON orders(inserted_at);
```

### Tabla: `order_items`
```sql
CREATE TABLE order_items (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id    UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id  UUID NOT NULL REFERENCES products(id),
  name        VARCHAR(255) NOT NULL,     -- snapshot del nombre
  image_url   TEXT,                       -- snapshot de la primera imagen
  price       INTEGER NOT NULL,          -- snapshot del precio
  quantity    INTEGER NOT NULL CHECK (quantity > 0),
  inserted_at TIMESTAMP NOT NULL DEFAULT NOW()
);
CREATE INDEX ON order_items(order_id);
```

---

## Schemas Ecto

### User Schema (`lib/ms_backend/accounts/user.ex`)
```elixir
schema "users" do
  field :name,          :string
  field :email,         :string
  field :password_hash, :string
  field :password,      :string, virtual: true
  field :address,       :string
  field :role,          :string, default: "user"
  timestamps()
end

def changeset(user, attrs) do
  user
  |> cast(attrs, [:name, :email, :password, :address, :role])
  |> validate_required([:name, :email, :password])
  |> validate_format(:email, ~r/@/)
  |> validate_length(:password, min: 8)
  |> unique_constraint(:email)
  |> hash_password()
end
```

### Product Schema (`lib/ms_backend/catalog/product.ex`)
```elixir
schema "products" do
  field :name,            :string
  field :description,     :string
  field :price,           :integer
  field :image_urls,      {:array, :string}, default: []
  field :type,            :string, default: "standard"
  field :sponsor_name,    :string
  field :sponsor_logo_url,:string
  field :sponsor_tagline, :string
  field :in_stock,        :boolean, default: true
  field :deleted_at,      :utc_datetime
  belongs_to :category, MsBackend.Catalog.Category
  timestamps()
end
```

### Order Schema (`lib/ms_backend/orders/order.ex`)
```elixir
schema "orders" do
  field :tracking_code,  :string
  field :status,         :string, default: "received"
  field :address,        :string
  field :payment_method, :string, default: "transfer"
  field :total,          :integer
  belongs_to :user, MsBackend.Accounts.User
  has_many :items, MsBackend.Orders.OrderItem
  timestamps()
end

@valid_statuses ~w(received preparing shipped delivered)
@status_transitions %{
  "received"  => "preparing",
  "preparing" => "shipped",
  "shipped"   => "delivered"
}
```

---

## Lógica de Negocio Clave

### Generación de tracking code (`orders.ex`)
```elixir
defp generate_tracking_code do
  suffix = :crypto.strong_rand_bytes(3) |> Base.encode16()
  "LIV-#{suffix}"
end
# Reintentar si hay colisión (unique constraint en BD)
```

### Avance de estado (`orders.ex`)
```elixir
def next_status("received"),  do: {:ok, "preparing"}
def next_status("preparing"), do: {:ok, "shipped"}
def next_status("shipped"),   do: {:ok, "delivered"}
def next_status("delivered"), do: {:error, "La orden ya fue entregada"}
def next_status(_),           do: {:error, "Estado inválido"}

def update_status(order, requested_status) do
  with {:ok, expected} <- next_status(order.status),
       true <- requested_status == expected do
    order |> Order.changeset(%{status: requested_status}) |> Repo.update()
  else
    _ -> {:error, :invalid_transition}
  end
end
```

### Email de confirmación (`mailer.ex`)
```elixir
def send_order_confirmation(user_email, tracking_code) do
  body = %{
    from: Application.get_env(:ms_backend, :resend_from),
    to: [user_email],
    subject: "Tu pedido ha sido recibido — Los Libros de Ivonnet",
    html: "<h2>¡Gracias por tu compra!</h2><p>Tu código de seguimiento es: <strong>#{tracking_code}</strong></p>"
  }
  # POST a https://api.resend.com/emails vía Finch
  # Si falla, loguear el error pero no propagar (no bloquear la orden)
  Task.start(fn -> do_send(body) end)
end
```

---

## Endpoints Completos

### Auth
| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| POST | `/api/auth/register` | Público | Registro comprador |
| POST | `/api/auth/login` | Público | Login comprador |
| POST | `/api/auth/admin/login` | Público | Login admin |
| DELETE | `/api/auth/logout` | Auth | Logout (invalida token en cliente) |
| GET | `/api/auth/me` | Auth | Perfil del usuario actual |

### Storefront (público o auth)
| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| GET | `/api/storefront/products` | Público | Lista productos activos |
| GET | `/api/storefront/products/:id` | Público | Detalle de producto |
| GET | `/api/storefront/categories` | Público | Lista categorías |
| POST | `/api/storefront/orders` | Auth (user) | Crear orden |
| GET | `/api/storefront/orders` | Auth (user) | Mis órdenes |
| GET | `/api/storefront/orders/:code` | Público | Tracking por código |

### Admin (solo role=admin)
| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| GET | `/api/admin/products` | Admin | Lista productos (incl. soft-deleted) |
| POST | `/api/admin/products` | Admin | Crear producto |
| PUT | `/api/admin/products/:id` | Admin | Editar producto |
| DELETE | `/api/admin/products/:id` | Admin | Soft delete producto |
| GET | `/api/admin/categories` | Admin | Lista categorías |
| POST | `/api/admin/categories` | Admin | Crear categoría |
| PUT | `/api/admin/categories/:id` | Admin | Editar categoría |
| DELETE | `/api/admin/categories/:id` | Admin | Eliminar categoría |
| GET | `/api/admin/orders` | Admin | Lista todas las órdenes (con filtros) |
| PUT | `/api/admin/orders/:id/status` | Admin | Actualizar estado de orden |
| GET | `/api/admin/stats/sales` | Admin | Ventas por mes |
| GET | `/api/admin/stats/products` | Admin | Top productos |
| GET | `/api/admin/stats/monthly` | Admin | Métricas del mes actual |

---

## Queries de Estadísticas

### Ventas por mes (stats_controller.ex)
```sql
SELECT
  to_char(inserted_at, 'YYYY-MM') AS month,
  SUM(total) AS total_amount,
  COUNT(*) AS order_count
FROM orders
WHERE inserted_at BETWEEN $1 AND $2
  AND status != 'received'  -- solo órdenes en proceso o entregadas
GROUP BY month
ORDER BY month ASC
```

### Top productos más vendidos
```sql
SELECT
  p.id AS product_id,
  p.name,
  SUM(oi.quantity) AS units_sold,
  SUM(oi.price * oi.quantity) AS revenue
FROM order_items oi
JOIN products p ON p.id = oi.product_id
JOIN orders o ON o.id = oi.order_id
WHERE o.inserted_at BETWEEN $1 AND $2
GROUP BY p.id, p.name
ORDER BY units_sold DESC
LIMIT $3
```

---

## Archivos a Crear/Modificar

| Archivo | Acción | Descripción |
|---------|--------|-------------|
| `mix.exs` | Modificar | Agregar dep `bcrypt_elixir` |
| `priv/repo/migrations/001_create_users.exs` | Crear | Migración tabla users |
| `priv/repo/migrations/002_create_categories.exs` | Crear | Migración tabla categories |
| `priv/repo/migrations/003_create_products.exs` | Crear | Migración tabla products |
| `priv/repo/migrations/004_create_orders.exs` | Crear | Migración tabla orders |
| `priv/repo/migrations/005_create_order_items.exs` | Crear | Migración tabla order_items |
| `lib/ms_backend/accounts/user.ex` | Crear | Schema + changeset |
| `lib/ms_backend/accounts/accounts.ex` | Crear | Context: register, login, get_user |
| `lib/ms_backend/catalog/category.ex` | Crear | Schema categoría |
| `lib/ms_backend/catalog/product.ex` | Crear | Schema producto |
| `lib/ms_backend/catalog/catalog.ex` | Crear | Context CRUD productos y categorías |
| `lib/ms_backend/orders/order.ex` | Crear | Schema orden |
| `lib/ms_backend/orders/order_item.ex` | Crear | Schema item de orden |
| `lib/ms_backend/orders/orders.ex` | Crear | Context: create_order, tracking, update_status, stats |
| `lib/ms_backend/mailer.ex` | Crear | Envío email via Resend/Finch |
| `lib/ms_backend/auth.ex` | Modificar | Ya existe scaffold, completar verify/generate |
| `lib/ms_backend_web/controllers/auth_controller.ex` | Crear | Endpoints de auth |
| `lib/ms_backend_web/controllers/product_controller.ex` | Crear | Endpoints de productos |
| `lib/ms_backend_web/controllers/category_controller.ex` | Crear | Endpoints de categorías |
| `lib/ms_backend_web/controllers/order_controller.ex` | Crear | Endpoints de órdenes |
| `lib/ms_backend_web/controllers/stats_controller.ex` | Crear | Endpoints de estadísticas |
| `lib/ms_backend_web/views/*.ex` | Crear | Views JSON para cada controller |
| `lib/ms_backend_web/router.ex` | Modificar | Ya existe scaffold, rutas correctas |
| `lib/ms_backend_web/plugs/require_auth.ex` | Modificar | Ya existe scaffold, completar |
| `lib/ms_backend_web/plugs/require_admin.ex` | Modificar | Ya existe scaffold, completar |
| `config/dev.exs` | Modificar | Credenciales BD dev locales |

---

## Consideraciones

- **bcrypt**: agregar `{:bcrypt_elixir, "~> 3.0"}` al `mix.exs`. Hasheo con `Bcrypt.hash_pwd_salt/1` y verificación con `Bcrypt.verify_pass/2`.
- **Precio en enteros**: guardar precios en pesos enteros (sin decimales) para evitar problemas de punto flotante en SQL. Ej: $85.000 COP → `85000`.
- **Tracking code collision**: usar `Repo.insert` con `on_conflict: :raise` y reintentar en caso de conflicto de unique constraint.
- **Email async**: el envío de email se hace en `Task.start` para no bloquear la respuesta HTTP. Los errores se loguean pero no se propagan.
- **CORS**: en `dev.exs`, Corsica permite `*`; en producción debe configurarse con los dominios exactos del storefront y admin.
- **Paginación**: todas las listas usan `Repo.paginate/2` (o implementación manual con `limit/offset`) con valores por defecto `page=1, per_page=20`.
- **Timestamps UTC**: todas las fechas en UTC en la BD. Los frontends convierten a hora local.
