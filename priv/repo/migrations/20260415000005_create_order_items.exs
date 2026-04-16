defmodule MsBackend.Repo.Migrations.CreateOrderItems do
  use Ecto.Migration

  def change do
    create table(:order_items, primary_key: false) do
      add :id,        :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :name,      :string,  null: false
      add :image_url, :text
      add :price,     :integer, null: false
      add :quantity,  :integer, null: false

      add :order_id, references(:orders, type: :binary_id, on_delete: :delete_all),
        null: false

      add :product_id, references(:products, type: :binary_id, on_delete: :restrict),
        null: false

      add :inserted_at, :utc_datetime, null: false, default: fragment("NOW()")
    end

    create index(:order_items, [:order_id])
  end
end
