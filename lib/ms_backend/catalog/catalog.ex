defmodule MsBackend.Catalog do
  import Ecto.Query
  alias MsBackend.Repo
  alias MsBackend.Catalog.{Category, Product}

  # ── Categorías ────────────────────────────────────────────────

  def list_categories do
    Category
    |> order_by([c], c.name)
    |> Repo.all()
  end

  def get_category(id), do: Repo.get(Category, id)

  def create_category(attrs) do
    %Category{}
    |> Category.changeset(attrs)
    |> Repo.insert()
  end

  def update_category(%Category{} = cat, attrs) do
    cat
    |> Category.changeset(attrs)
    |> Repo.update()
  end

  def delete_category(%Category{} = cat) do
    active_count =
      Product
      |> where([p], p.category_id == ^cat.id and is_nil(p.deleted_at))
      |> Repo.aggregate(:count, :id)

    if active_count > 0 do
      {:error, :has_products}
    else
      Repo.delete(cat)
    end
  end

  # ── Productos ─────────────────────────────────────────────────

  @default_page     1
  @default_per_page 20

  def list_products(opts \\ []) do
    page        = Keyword.get(opts, :page, @default_page)
    per_page    = Keyword.get(opts, :per_page, @default_per_page)
    category_id = Keyword.get(opts, :category_id)
    include_deleted = Keyword.get(opts, :include_deleted, false)

    offset = (page - 1) * per_page

    base =
      Product
      |> preload(:category)
      |> order_by([p], [desc: p.inserted_at])

    base = if category_id, do: where(base, [p], p.category_id == ^category_id), else: base
    base = if include_deleted, do: base, else: where(base, [p], is_nil(p.deleted_at))

    total   = Repo.aggregate(base, :count, :id)
    records = base |> limit(^per_page) |> offset(^offset) |> Repo.all()

    %{data: records, meta: %{total: total, page: page, per_page: per_page}}
  end

  def get_product(id), do: Repo.get(Product, id) |> maybe_preload_category()

  def get_active_product(id) do
    Product
    |> where([p], p.id == ^id and is_nil(p.deleted_at))
    |> Repo.one()
    |> maybe_preload_category()
  end

  def create_product(attrs) do
    %Product{}
    |> Product.changeset(attrs)
    |> Repo.insert()
  end

  def update_product(%Product{} = product, attrs) do
    product
    |> Product.changeset(attrs)
    |> Repo.update()
  end

  def soft_delete_product(%Product{} = product) do
    product
    |> Ecto.Changeset.change(deleted_at: DateTime.utc_now() |> DateTime.truncate(:second))
    |> Repo.update()
  end

  # ── helpers ───────────────────────────────────────────────────

  defp maybe_preload_category(nil), do: nil
  defp maybe_preload_category(product), do: Repo.preload(product, :category)
end
