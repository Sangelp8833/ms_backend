defmodule MsBackend.Catalog.Product do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "products" do
    field :name,             :string
    field :description,      :string
    field :price,            :integer
    field :image_urls,       {:array, :string}, default: []
    field :type,             :string, default: "standard"
    field :sponsor_name,     :string
    field :sponsor_logo_url, :string
    field :sponsor_tagline,  :string
    field :in_stock,         :boolean, default: true
    field :deleted_at,       :utc_datetime

    belongs_to :category, MsBackend.Catalog.Category

    timestamps(type: :utc_datetime)
  end

  def changeset(product, attrs) do
    product
    |> cast(attrs, [
      :name, :description, :price, :image_urls, :type,
      :sponsor_name, :sponsor_logo_url, :sponsor_tagline,
      :in_stock, :category_id
    ])
    |> validate_required([:name, :price, :category_id])
    |> validate_number(:price, greater_than: 0, message: "debe ser mayor a 0")
    |> validate_inclusion(:type, ["standard", "sponsored"])
    |> validate_sponsored_fields()
    |> assoc_constraint(:category)
  end

  defp validate_sponsored_fields(%Ecto.Changeset{} = cs) do
    type = get_field(cs, :type)
    if type == "sponsored" do
      validate_required(cs, [:sponsor_name], message: "requerido para productos patrocinados")
    else
      cs
    end
  end
end
