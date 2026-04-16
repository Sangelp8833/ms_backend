defmodule MsBackend.Orders.OrderItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "order_items" do
    field :name,      :string
    field :image_url, :string
    field :price,     :integer
    field :quantity,  :integer

    belongs_to :order,   MsBackend.Orders.Order
    belongs_to :product, MsBackend.Catalog.Product

    field :inserted_at, :utc_datetime, autogenerate: {DateTime, :utc_now, []}
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:order_id, :product_id, :name, :image_url, :price, :quantity])
    |> validate_required([:product_id, :name, :price, :quantity])
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:price,    greater_than: 0)
  end
end
