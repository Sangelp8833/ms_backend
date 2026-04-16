defmodule MsBackend.Orders.Order do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_statuses  ~w(received preparing shipped delivered)
  @status_next     %{
    "received"  => "preparing",
    "preparing" => "shipped",
    "shipped"   => "delivered"
  }

  schema "orders" do
    field :tracking_code,  :string
    field :status,         :string, default: "received"
    field :address,        :string
    field :payment_method, :string, default: "transfer"
    field :total,          :integer

    belongs_to :user, MsBackend.Accounts.User
    has_many   :items, MsBackend.Orders.OrderItem

    timestamps(type: :utc_datetime)
  end

  def changeset(order, attrs) do
    order
    |> cast(attrs, [:tracking_code, :status, :address, :payment_method, :total, :user_id])
    |> validate_required([:tracking_code, :address, :total, :user_id])
    |> validate_inclusion(:status, @valid_statuses)
    |> unique_constraint(:tracking_code)
  end

  @doc "Retorna el siguiente estado válido o error si ya está en el final."
  def next_status("delivered"), do: {:error, :already_delivered}
  def next_status(current) do
    case Map.get(@status_next, current) do
      nil  -> {:error, :invalid_status}
      next -> {:ok, next}
    end
  end
end
