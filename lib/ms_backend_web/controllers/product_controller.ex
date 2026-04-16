defmodule MsBackendWeb.ProductController do
  use MsBackendWeb, :controller

  alias MsBackend.Catalog

  # GET /api/storefront/products  (público)
  def index(conn, params) do
    opts = [
      page:        parse_int(params["page"], 1),
      per_page:    parse_int(params["per_page"], 20),
      category_id: params["category_id"],
      include_deleted: false
    ]

    %{data: products, meta: meta} = Catalog.list_products(opts)

    conn
    |> json(%{
      data: Enum.map(products, &product_json/1),
      meta: %{total: meta.total, page: meta.page, per_page: meta.per_page}
    })
  end

  # GET /api/storefront/products/:id  (público)
  def show(conn, %{"id" => id}) do
    case Catalog.get_active_product(id) do
      nil     -> conn |> put_status(:not_found) |> json(%{error: "Producto no encontrado"})
      product -> json(conn, %{data: product_json(product)})
    end
  end

  # GET /api/admin/products  (admin)
  def admin_index(conn, params) do
    opts = [
      page:            parse_int(params["page"], 1),
      per_page:        parse_int(params["per_page"], 20),
      category_id:     params["category_id"],
      include_deleted: params["include_deleted"] == "true"
    ]

    %{data: products, meta: meta} = Catalog.list_products(opts)

    conn
    |> json(%{
      data: Enum.map(products, &product_json/1),
      meta: %{total: meta.total, page: meta.page, per_page: meta.per_page}
    })
  end

  # POST /api/admin/products  (admin)
  def create(conn, params) do
    attrs = product_attrs(params)

    case Catalog.create_product(attrs) do
      {:ok, product} ->
        product = MsBackend.Repo.preload(product, :category)
        conn |> put_status(:created) |> json(%{data: product_json(product)})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(changeset)})
    end
  end

  # PUT /api/admin/products/:id  (admin)
  def update(conn, %{"id" => id} = params) do
    case Catalog.get_product(id) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "Producto no encontrado"})
      product ->
        case Catalog.update_product(product, product_attrs(params)) do
          {:ok, updated} ->
            updated = MsBackend.Repo.preload(updated, :category)
            json(conn, %{data: product_json(updated)})

          {:error, changeset} ->
            conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(changeset)})
        end
    end
  end

  # DELETE /api/admin/products/:id  (admin)
  def delete(conn, %{"id" => id}) do
    case Catalog.get_product(id) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "Producto no encontrado"})
      product ->
        {:ok, deleted} = Catalog.soft_delete_product(product)
        deleted = MsBackend.Repo.preload(deleted, :category)
        json(conn, %{data: product_json(deleted)})
    end
  end

  # ── helpers ───────────────────────────────────────────────────

  defp product_json(p) do
    base = %{
      id:           p.id,
      name:         p.name,
      description:  p.description,
      price:        p.price,
      image_urls:   p.image_urls,
      type:         p.type,
      in_stock:     p.in_stock,
      deleted_at:   p.deleted_at,
      category_id:  p.category_id,
      category_name: (p.category && p.category.name) || nil,
      inserted_at:  p.inserted_at,
      updated_at:   p.updated_at
    }

    if p.type == "sponsored" do
      Map.put(base, :sponsor_info, %{
        name:     p.sponsor_name,
        logo_url: p.sponsor_logo_url,
        tagline:  p.sponsor_tagline
      })
    else
      base
    end
  end

  defp product_attrs(params) do
    %{
      "name"             => params["name"],
      "description"      => params["description"],
      "price"            => parse_int(params["price"], nil),
      "image_urls"       => params["image_urls"] || [],
      "type"             => params["type"] || "standard",
      "sponsor_name"     => params["sponsor_name"],
      "sponsor_logo_url" => params["sponsor_logo_url"],
      "sponsor_tagline"  => params["sponsor_tagline"],
      "in_stock"         => params["in_stock"] != "false" && params["in_stock"] != false,
      "category_id"      => params["category_id"]
    }
  end

  defp parse_int(nil, default), do: default
  defp parse_int(val, default) when is_integer(val), do: val
  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> default
    end
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
