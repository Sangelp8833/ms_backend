defmodule MsBackendWeb.OrderController do
  use MsBackendWeb, :controller

  alias MsBackend.{Accounts, Orders}
  alias MsBackend.Orders.Order

  # POST /api/storefront/orders  (auth user)
  def create(conn, params) do
    user = Accounts.get_user(conn.assigns.current_user_id)

    case Orders.create_order(user, params) do
      {:ok, order} ->
        conn
        |> put_status(:created)
        |> json(%{order: order_json(order)})

      {:error, errors} when is_list(errors) ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: errors})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: to_string(reason)})
    end
  end

  # GET /api/storefront/orders  (auth user)
  def my_orders(conn, _params) do
    orders = Orders.list_orders_for_user(conn.assigns.current_user_id)
    json(conn, %{data: Enum.map(orders, &order_json/1)})
  end

  # GET /api/storefront/orders/:code  (público)
  def track(conn, %{"code" => code}) do
    case Orders.get_by_tracking_code(code) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Código de pedido no encontrado"})

      order ->
        json(conn, %{order: %{
          tracking_code: order.tracking_code,
          status:        order.status,
          created_at:    order.inserted_at,
          updated_at:    order.updated_at
        }})
    end
  end

  # GET /api/admin/orders  (admin)
  def admin_index(conn, params) do
    from = parse_datetime(params["from"])
    to   = parse_datetime(params["to"])

    opts = [
      page:     parse_int(params["page"], 1),
      per_page: parse_int(params["per_page"], 20),
      status:   params["status"],
      query:    params["q"],
      from:     from,
      to:       to
    ]

    %{data: orders, meta: meta} = Orders.list_all_orders(opts)

    json(conn, %{
      data: Enum.map(orders, &order_json/1),
      meta: %{total: meta.total, page: meta.page, per_page: meta.per_page}
    })
  end

  # PUT /api/admin/orders/:id/status  (admin)
  def update_status(conn, %{"id" => id, "status" => new_status}) do
    case Orders.get_order_with_items(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Orden no encontrada"})

      order ->
        case Orders.update_status(order, new_status) do
          {:ok, updated} ->
            updated = MsBackend.Repo.preload(updated, [:items, :user])
            json(conn, %{order: order_json(updated)})

          {:error, msg} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: msg})
        end
    end
  end

  # ── helpers ───────────────────────────────────────────────────

  defp order_json(%Order{} = o) do
    %{
      id:             o.id,
      tracking_code:  o.tracking_code,
      status:         o.status,
      address:        o.address,
      payment_method: o.payment_method,
      total:          o.total,
      customer_name:  o.user && o.user.name,
      customer_email: o.user && o.user.email,
      items:          Enum.map(o.items || [], &item_json/1),
      created_at:     o.inserted_at,
      updated_at:     o.updated_at
    }
  end

  defp item_json(i) do
    %{
      product_id: i.product_id,
      name:       i.name,
      image_url:  i.image_url,
      price:      i.price,
      quantity:   i.quantity
    }
  end

  defp parse_int(nil, default), do: default
  defp parse_int(val, default) when is_integer(val), do: val
  defp parse_int(val, default) do
    case Integer.parse(to_string(val)) do
      {n, _} -> n
      :error -> default
    end
  end

  defp parse_datetime(nil), do: nil
  defp parse_datetime(str) do
    case DateTime.from_iso8601(str <> "T00:00:00Z") do
      {:ok, dt, _} -> dt
      _            ->
        case DateTime.from_iso8601(str) do
          {:ok, dt, _} -> dt
          _            -> nil
        end
    end
  end
end
