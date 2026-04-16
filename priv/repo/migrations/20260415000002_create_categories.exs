defmodule MsBackend.Repo.Migrations.CreateCategories do
  use Ecto.Migration

  def change do
    create table(:categories, primary_key: false) do
      add :id,   :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :name, :string, null: false
      add :slug, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:categories, [:slug])
  end
end
