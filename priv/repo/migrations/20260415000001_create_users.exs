defmodule MsBackend.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", ""
    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto", ""

    create table(:users, primary_key: false) do
      add :id,            :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :name,          :string,    null: false
      add :email,         :string,    null: false
      add :password_hash, :string,    null: false
      add :address,       :text
      add :role,          :string,    null: false, default: "user"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
  end
end
