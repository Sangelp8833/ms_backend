defmodule MsBackend.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    create table(:products, primary_key: false) do
      add :id,               :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :name,             :string,    null: false
      add :description,      :text
      add :price,            :integer,   null: false
      add :image_urls,       {:array, :text}, null: false, default: []
      add :type,             :string,    null: false, default: "standard"
      add :sponsor_name,     :string
      add :sponsor_logo_url, :text
      add :sponsor_tagline,  :string
      add :in_stock,         :boolean,   null: false, default: true
      add :deleted_at,       :utc_datetime

      add :category_id, references(:categories, type: :binary_id, on_delete: :restrict),
        null: false

      timestamps(type: :utc_datetime)
    end

    create index(:products, [:category_id])
    create index(:products, [:deleted_at])
  end
end
