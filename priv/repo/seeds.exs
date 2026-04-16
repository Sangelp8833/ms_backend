alias MsBackend.Repo
alias MsBackend.Accounts.User
alias MsBackend.Catalog.{Category, Product}
alias MsBackend.Orders.{Order, OrderItem}
import Ecto.Query

IO.puts("==> Seeding Los Libros de Ivonnet...")

# ── Limpiar (orden por FK) ────────────────────────────────────
Repo.delete_all(OrderItem)
Repo.delete_all(Order)
Repo.delete_all(Product)
Repo.delete_all(Category)
Repo.delete_all(User)

# ── Usuarios ─────────────────────────────────────────────────

{:ok, admin} =
  %User{}
  |> User.changeset(%{
    name:     "Ivonnet Pérez",
    email:    "admin@loslibrosdivonnet.com",
    password: "Admin1234!",
    address:  "Calle de las Letras 1, Bogotá",
    role:     "admin"
  })
  |> Repo.insert()

IO.puts("   Admin: #{admin.email}")

{:ok, buyer} =
  %User{}
  |> User.changeset(%{
    name:     "Lector Ejemplo",
    email:    "lector@ejemplo.com",
    password: "Lector1234!",
    address:  "Carrera de los Libros 42, Medellín",
    role:     "user"
  })
  |> Repo.insert()

IO.puts("   Comprador: #{buyer.email}")

# ── Categorías ───────────────────────────────────────────────

categories =
  Enum.map(
    [
      %{name: "Kits de Libros"},
      %{name: "Libretas Personalizadas"},
      %{name: "Mocks y Ediciones Especiales"},
      %{name: "Productos de Marca"}
    ],
    fn attrs ->
      {:ok, cat} = %Category{} |> Category.changeset(attrs) |> Repo.insert()
      IO.puts("   Categoría: #{cat.name} (#{cat.slug})")
      cat
    end
  )

[cat_kits, cat_libretas, cat_mocks, cat_marca] = categories

# ── Productos estándar ────────────────────────────────────────

{:ok, p1} =
  %Product{}
  |> Product.changeset(%{
    name:        "Kit Clásicos Latinoamericanos",
    description: "Una selección cuidadosa de cinco novelas fundacionales de América Latina. Incluye: Cien años de soledad, Pedro Páramo, El Señor Presidente, La vorágine y Ficciones. Cada libro viene con una nota introductoria escrita por Ivonnet.",
    price:       18_500_0,
    image_urls:  ["https://picsum.photos/seed/kit-clasicos/600/400"],
    category_id: cat_kits.id,
    type:        "standard",
    in_stock:    true
  })
  |> Repo.insert()

{:ok, p2} =
  %Product{}
  |> Product.changeset(%{
    name:        "Kit Poesía del Caribe",
    description: "Cinco voces poéticas del Caribe hispano. Incluye poemarios de José Martí, Nicolás Guillén, Eugenio Florit, Manuel del Cabral y Ida Vitale. Formato bolsillo, ideal para leer en cualquier lugar.",
    price:       12_000_0,
    image_urls:  ["https://picsum.photos/seed/kit-poesia/600/400"],
    category_id: cat_kits.id,
    type:        "standard",
    in_stock:    true
  })
  |> Repo.insert()

{:ok, p3} =
  %Product{}
  |> Product.changeset(%{
    name:        "Libreta Cuero Personalizada",
    description: "Libreta artesanal con cubierta de cuero vegano. 120 páginas rayadas, papel crema 90 gr. Puedes personalizar la frase que va grabada en la portada al momento del pedido.",
    price:       8_500_0,
    image_urls:  ["https://picsum.photos/seed/libreta-cuero/600/400"],
    category_id: cat_libretas.id,
    type:        "standard",
    in_stock:    true
  })
  |> Repo.insert()

{:ok, p4} =
  %Product{}
  |> Product.changeset(%{
    name:        "Libreta Acuarela «Palabras que pintan»",
    description: "Libreta de 80 páginas con cubierta ilustrada a mano en acuarela por la artista Camila Reyes. Papel blanco 100 gr, hojas sin pauta. Cada unidad es única.",
    price:       9_200_0,
    image_urls:  ["https://picsum.photos/seed/libreta-acuarela/600/400"],
    category_id: cat_libretas.id,
    type:        "standard",
    in_stock:    true
  })
  |> Repo.insert()

{:ok, p5} =
  %Product{}
  |> Product.changeset(%{
    name:        "Mock «Edición Dorada» — García Márquez",
    description: "Réplica premium de la primera edición de Cien años de soledad. Cubierta dura con laminado dorado, 422 páginas. Pieza de colección, no apta para lectura casual.",
    price:       45_000_0,
    image_urls:  ["https://picsum.photos/seed/mock-cem-anos/600/400"],
    category_id: cat_mocks.id,
    type:        "standard",
    in_stock:    true
  })
  |> Repo.insert()

# ── Producto sponsored ────────────────────────────────────────

{:ok, p6} =
  %Product{}
  |> Product.changeset(%{
    name:          "Kit Novela Negra — Selección Tintero",
    description:   "Cinco novelas policiales imprescindibles seleccionadas por la Librería Tintero de Bogotá. Incluye: El nombre de la rosa, El caso Savolta, El invierno en Lisboa, La tabla de Flandes y Carvalho en las Antípodas.",
    price:         22_000_0,
    image_urls:    ["https://picsum.photos/seed/kit-negra/600/400"],
    category_id:   cat_kits.id,
    type:          "sponsored",
    sponsor_name:  "Librería Tintero",
    sponsor_logo_url: "https://picsum.photos/seed/tintero-logo/200/200",
    sponsor_tagline: "La librería que hace pensar desde 1987",
    in_stock:      true
  })
  |> Repo.insert()

{:ok, p7} =
  %Product{}
  |> Product.changeset(%{
    name:          "Kit Ciencia Ficción Clásica — Casa Gutenberg",
    description:   "La trilogía fundacional del género: Dune, Fundación y El fin de la eternidad. Ediciones de bolsillo con prólogos exclusivos. Curado por Casa Gutenberg de Cali.",
    price:         19_500_0,
    image_urls:    ["https://picsum.photos/seed/kit-scifi/600/400"],
    category_id:   cat_kits.id,
    type:          "sponsored",
    sponsor_name:  "Casa Gutenberg",
    sponsor_logo_url: "https://picsum.photos/seed/gutenberg-logo/200/200",
    sponsor_tagline: "Libros para imaginar futuros posibles",
    in_stock:      true
  })
  |> Repo.insert()

{:ok, p8} =
  %Product{}
  |> Product.changeset(%{
    name:        "Marcapáginas Artesanales — Pack x10",
    description: "Diez marcapáginas de cuero con citas literarias grabadas. Diseñados y fabricados en el taller de Los Libros de Ivonnet. Ideales como regalo.",
    price:       3_500_0,
    image_urls:  ["https://picsum.photos/seed/marcapaginas/600/400"],
    category_id: cat_marca.id,
    type:        "standard",
    in_stock:    true
  })
  |> Repo.insert()

products = [p1, p2, p3, p4, p5, p6, p7, p8]
IO.puts("   #{length(products)} productos creados")

# ── Órdenes de ejemplo ────────────────────────────────────────

# Orden entregada
{:ok, order1} =
  %Order{}
  |> Order.changeset(%{
    tracking_code:  "LIV-A1B2C3",
    user_id:        buyer.id,
    address:        "Carrera de los Libros 42, Medellín",
    payment_method: "transfer",
    total:          41_000_0,
    status:         "delivered"
  })
  |> Repo.insert()

Repo.insert!(%OrderItem{
  order_id:   order1.id,
  product_id: p1.id,
  name:       p1.name,
  image_url:  List.first(p1.image_urls),
  price:      p1.price,
  quantity:   1
})
Repo.insert!(%OrderItem{
  order_id:   order1.id,
  product_id: p3.id,
  name:       p3.name,
  image_url:  List.first(p3.image_urls),
  price:      p3.price,
  quantity:   1
})

# Orden en camino
{:ok, order2} =
  %Order{}
  |> Order.changeset(%{
    tracking_code:  "LIV-D4E5F6",
    user_id:        buyer.id,
    address:        "Carrera de los Libros 42, Medellín",
    payment_method: "cash",
    total:          22_000_0,
    status:         "shipped"
  })
  |> Repo.insert()

Repo.insert!(%OrderItem{
  order_id:   order2.id,
  product_id: p6.id,
  name:       p6.name,
  image_url:  List.first(p6.image_urls),
  price:      p6.price,
  quantity:   1
})

# Orden recibida (pendiente)
{:ok, order3} =
  %Order{}
  |> Order.changeset(%{
    tracking_code:  "LIV-G7H8I9",
    user_id:        buyer.id,
    address:        "Carrera de los Libros 42, Medellín",
    payment_method: "transfer",
    total:          54_000_0,
    status:         "received"
  })
  |> Repo.insert()

Repo.insert!(%OrderItem{
  order_id:   order3.id,
  product_id: p5.id,
  name:       p5.name,
  image_url:  List.first(p5.image_urls),
  price:      p5.price,
  quantity:   1
})
Repo.insert!(%OrderItem{
  order_id:   order3.id,
  product_id: p8.id,
  name:       p8.name,
  image_url:  List.first(p8.image_urls),
  price:      p8.price,
  quantity:   3
})

IO.puts("   3 órdenes de ejemplo creadas")
IO.puts("")
IO.puts("==> Seeds completos!")
IO.puts("")
IO.puts("    Admin:     admin@loslibrosdivonnet.com / Admin1234!")
IO.puts("    Comprador: lector@ejemplo.com / Lector1234!")
IO.puts("    Tracking:  LIV-A1B2C3 (entregada) | LIV-D4E5F6 (en camino) | LIV-G7H8I9 (recibida)")
