defmodule MsBackend.Catalog.Category do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "categories" do
    field :name, :string
    field :slug, :string

    has_many :products, MsBackend.Catalog.Product

    timestamps(type: :utc_datetime)
  end

  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :slug])
    |> validate_required([:name])
    |> maybe_generate_slug()
    |> unique_constraint(:slug, message: "este slug ya existe")
  end

  defp maybe_generate_slug(%Ecto.Changeset{changes: %{slug: _}} = cs), do: cs
  defp maybe_generate_slug(%Ecto.Changeset{changes: %{name: name}} = cs) do
    slug =
      name
      |> String.downcase()
      |> String.normalize(:nfd)
      |> String.replace(~r/[^a-z0-9\s-]/u, "")
      |> String.replace(~r/\s+/, "-")
      |> String.trim("-")

    put_change(cs, :slug, slug)
  end
  defp maybe_generate_slug(cs), do: cs
end
