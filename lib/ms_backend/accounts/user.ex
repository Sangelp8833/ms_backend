defmodule MsBackend.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :name,          :string
    field :email,         :string
    field :password,      :string, virtual: true
    field :password_hash, :string
    field :address,       :string
    field :role,          :string, default: "user"

    timestamps(type: :utc_datetime)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :password, :address, :role])
    |> validate_required([:name, :email, :password])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "formato de email inválido")
    |> validate_length(:password, min: 8, message: "mínimo 8 caracteres")
    |> validate_inclusion(:role, ["user", "admin"])
    |> unique_constraint(:email, message: "este email ya está registrado")
    |> hash_password()
  end

  def update_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :address])
    |> validate_required([:name])
  end

  defp hash_password(%Ecto.Changeset{valid?: true, changes: %{password: pw}} = cs) do
    put_change(cs, :password_hash, Pbkdf2.hash_pwd_salt(pw))
  end
  defp hash_password(cs), do: cs
end
