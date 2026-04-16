defmodule MsBackend.Repo.Migrations.CreateOrders do
  use Ecto.Migration

  def change do
    create table(:orders, primary_key: false) do
      add :id,             :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :tracking_code,  :string,    null: false
      add :status,         :string,    null: false, default: "received"
      add :address,        :text,      null: false
      add :payment_method, :string,    null: false, default: "transfer"
      add :total,          :integer,   null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :restrict),
        null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:orders, [:tracking_code])
    create index(:orders, [:user_id])
    create index(:orders, [:status])
    create index(:orders, [:inserted_at])
  end
end
