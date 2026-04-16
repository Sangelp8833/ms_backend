defmodule MsBackend.Orders do
  import Ecto.Query
  alias MsBackend.Repo
  alias MsBackend.Orders.{Order, OrderItem}
  alias MsBackend.Catalog

  # ── Crear orden ───────────────────────────────────────────────

  def create_order(user, %{"items" => items_attrs, "address" => address} = attrs) do
    payment_method = attrs["payment_method"] || "transfer"

    with {:ok, resolved_items} <- resolve_items(items_attrs),
         total                  <- calc_total(resolved_items),
         {:ok, tracking_code}   <- generate_unique_tracking_code() do

      Repo.transaction(fn ->
        order =
          %Order{}
          |> Order.changeset(%{
            tracking_code:  tracking_code,
            user_id:        user.id,
            address:        address,
            payment_method: payment_method,
            total:          total,
            status:         "received"
          })
          |> Repo.insert!()

        Enum.each(resolved_items, fn item ->
          %OrderItem{}
          |> OrderItem.changeset(%{
            order_id:   order.id,
            product_id: item.product_id,
            name:       item.name,
            image_url:  item.image_url,
            price:      item.price,
            quantity:   item.quantity
          })
          |> Repo.insert!()
        end)

        order = Repo.preload(order, [:items, :user])

        # Email async — no bloquea
        MsBackend.Mailer.send_order_confirmation(user.email, tracking_code)

        order
      end)
    end
  end

  # ── Tracking público ─────────────────────────────────────────

  def get_by_tracking_code(code) do
    Order
    |> where([o], o.tracking_code == ^code)
    |> Repo.one()
  end

  # ── Mis órdenes ───────────────────────────────────────────────

  def list_orders_for_user(user_id) do
    Order
    |> where([o], o.user_id == ^user_id)
    |> order_by([o], desc: o.inserted_at)
    |> preload(:items)
    |> Repo.all()
  end

  # ── Lista admin (con filtros) ─────────────────────────────────

  def list_all_orders(opts \\ []) do
    page     = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 20)
    status   = Keyword.get(opts, :status)
    from     = Keyword.get(opts, :from)
    to       = Keyword.get(opts, :to)
    query    = Keyword.get(opts, :query)

    offset = (page - 1) * per_page

    base =
      Order
      |> join(:left, [o], u in assoc(o, :user))
      |> preload([o, u], [items: [], user: u])
      |> order_by([o], desc: o.inserted_at)

    base = if status,  do: where(base, [o], o.status == ^status), else: base
    base = if from,    do: where(base, [o], o.inserted_at >= ^from), else: base
    base = if to,      do: where(base, [o], o.inserted_at <= ^to), else: base
    base =
      if query do
        like = "%#{query}%"
        where(base, [o, u], ilike(o.tracking_code, ^like) or ilike(u.email, ^like))
      else
        base
      end

    total   = Repo.aggregate(base, :count, :id)
    records = base |> limit(^per_page) |> offset(^offset) |> Repo.all()

    %{data: records, meta: %{total: total, page: page, per_page: per_page}}
  end

  # ── Detalle ───────────────────────────────────────────────────

  def get_order_with_items(id) do
    Order
    |> where([o], o.id == ^id)
    |> preload([:items, :user])
    |> Repo.one()
  end

  # ── Actualizar estado ─────────────────────────────────────────

  def update_status(%Order{} = order, requested_status) do
    case Order.next_status(order.status) do
      {:ok, expected} when expected == requested_status ->
        order
        |> Order.changeset(%{status: requested_status})
        |> Repo.update()

      {:ok, expected} ->
        {:error, "El siguiente estado válido es '#{expected}', no '#{requested_status}'"}

      {:error, :already_delivered} ->
        {:error, "La orden ya fue entregada"}

      {:error, _} ->
        {:error, "Estado de orden inválido"}
    end
  end

  # ── Stats ─────────────────────────────────────────────────────

  def sales_by_month(from, to) do
    Repo.all(
      from o in Order,
        where: o.inserted_at >= ^from and o.inserted_at <= ^to,
        where: o.status != "received",
        group_by: fragment("to_char(?, 'YYYY-MM')", o.inserted_at),
        select: %{
          month:        fragment("to_char(?, 'YYYY-MM')", o.inserted_at),
          total_amount: sum(o.total),
          order_count:  count(o.id)
        },
        order_by: fragment("to_char(?, 'YYYY-MM')", o.inserted_at)
    )
  end

  def top_products(from, to, limit \\ 10) do
    Repo.all(
      from oi in OrderItem,
        join: o  in assoc(oi, :order),
        join: p  in assoc(oi, :product),
        where: o.inserted_at >= ^from and o.inserted_at <= ^to,
        group_by: [p.id, p.name],
        select: %{
          product_id: p.id,
          name:       p.name,
          units_sold: sum(oi.quantity),
          revenue:    sum(oi.price * oi.quantity)
        },
        order_by: [desc: sum(oi.quantity)],
        limit: ^limit
    )
  end

  def monthly_stats do
    now        = DateTime.utc_now()
    month_start = %{now | day: 1, hour: 0, minute: 0, second: 0, microsecond: {0, 0}}

    monthly_sales =
      Repo.one(
        from o in Order,
          where: o.inserted_at >= ^month_start and o.status != "received",
          select: coalesce(sum(o.total), 0)
      )

    active_orders =
      Repo.aggregate(
        from(o in Order, where: o.status in ["received", "preparing", "shipped"]),
        :count, :id
      )

    pending_orders =
      Repo.aggregate(
        from(o in Order, where: o.status == "received"),
        :count, :id
      )

    active_products =
      Repo.aggregate(
        from(p in MsBackend.Catalog.Product, where: is_nil(p.deleted_at)),
        :count, :id
      )

    %{
      monthly_sales:   monthly_sales,
      active_orders:   active_orders,
      pending_orders:  pending_orders,
      active_products: active_products
    }
  end

  # ── private helpers ───────────────────────────────────────────

  defp resolve_items(items_attrs) do
    results =
      Enum.map(items_attrs, fn item ->
        product_id = item["product_id"]
        quantity   = item["quantity"] || 1

        case Catalog.get_active_product(product_id) do
          nil -> {:error, "Producto #{product_id} no encontrado o no disponible"}
          p   ->
            {:ok, %{
              product_id: p.id,
              name:       p.name,
              image_url:  List.first(p.image_urls),
              price:      p.price,
              quantity:   quantity
            }}
        end
      end)

    errors = for {:error, msg} <- results, do: msg

    if Enum.empty?(errors) do
      {:ok, for({:ok, item} <- results, do: item)}
    else
      {:error, errors}
    end
  end

  defp calc_total(items) do
    Enum.reduce(items, 0, fn i, acc -> acc + i.price * i.quantity end)
  end

  defp generate_unique_tracking_code(attempts \\ 0) when attempts < 10 do
    code = "LIV-" <> (:crypto.strong_rand_bytes(3) |> Base.encode16())

    case Repo.one(from o in Order, where: o.tracking_code == ^code, select: o.id) do
      nil -> {:ok, code}
      _   -> generate_unique_tracking_code(attempts + 1)
    end
  end
  defp generate_unique_tracking_code(_), do: {:error, "No se pudo generar código único"}
end
