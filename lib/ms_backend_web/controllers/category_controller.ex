defmodule MsBackendWeb.CategoryController do
  use MsBackendWeb, :controller

  alias MsBackend.Catalog

  # GET /api/storefront/categories  (público)
  def index(conn, _params) do
    categories = Catalog.list_categories()
    json(conn, %{data: Enum.map(categories, &cat_json/1)})
  end

  # POST /api/admin/categories  (admin)
  def create(conn, params) do
    case Catalog.create_category(params) do
      {:ok, cat} ->
        conn |> put_status(:created) |> json(%{data: cat_json(cat)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  # PUT /api/admin/categories/:id  (admin)
  def update(conn, %{"id" => id} = params) do
    case Catalog.get_category(id) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "Categoría no encontrada"})
      cat ->
        case Catalog.update_category(cat, params) do
          {:ok, updated} -> json(conn, %{data: cat_json(updated)})
          {:error, cs}   -> conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(cs)})
        end
    end
  end

  # DELETE /api/admin/categories/:id  (admin)
  def delete(conn, %{"id" => id}) do
    case Catalog.get_category(id) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "Categoría no encontrada"})
      cat ->
        case Catalog.delete_category(cat) do
          {:ok, _}             -> json(conn, %{ok: true})
          {:error, :has_products} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "No se puede eliminar: tiene productos activos asociados"})
        end
    end
  end

  # ── helpers ───────────────────────────────────────────────────

  defp cat_json(c), do: %{id: c.id, name: c.name, slug: c.slug}

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
