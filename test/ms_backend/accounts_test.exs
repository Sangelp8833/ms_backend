defmodule MsBackend.AccountsTest do
  use MsBackend.DataCase

  alias MsBackend.Accounts
  alias MsBackend.Accounts.User

  describe "register_user/1" do
    test "crea usuario con datos válidos" do
      attrs = valid_user_attrs()
      assert {:ok, %User{} = user} = Accounts.register_user(attrs)
      assert user.name  == attrs["name"]
      assert user.email == attrs["email"]
      assert user.role  == "user"
      refute is_nil(user.password_hash)
    end

    test "falla si falta email" do
      attrs = valid_user_attrs() |> Map.delete("email")
      assert {:error, changeset} = Accounts.register_user(attrs)
      assert %{email: _} = errors_on(changeset)
    end

    test "falla si falta password" do
      attrs = valid_user_attrs() |> Map.delete("password")
      assert {:error, changeset} = Accounts.register_user(attrs)
      assert %{password: _} = errors_on(changeset)
    end

    test "falla si password es muy corto" do
      attrs = valid_user_attrs(%{"password" => "abc"})
      assert {:error, changeset} = Accounts.register_user(attrs)
      assert %{password: _} = errors_on(changeset)
    end

    test "falla si email ya existe" do
      attrs = valid_user_attrs(%{"email" => "duplicate@example.com"})
      assert {:ok, _} = Accounts.register_user(attrs)
      assert {:error, changeset} = Accounts.register_user(attrs)
      assert %{email: _} = errors_on(changeset)
    end
  end

  describe "authenticate_user/2" do
    setup do
      {:ok, user} = Accounts.register_user(valid_user_attrs(%{"email" => "auth@test.com", "password" => "Password123!"}))
      %{user: user}
    end

    test "autentica con credenciales correctas", %{user: user} do
      assert {:ok, authenticated} = Accounts.authenticate_user(user.email, "Password123!")
      assert authenticated.id == user.id
    end

    test "falla con password incorrecto", %{user: user} do
      assert {:error, :invalid_credentials} = Accounts.authenticate_user(user.email, "wrong")
    end

    test "falla con email inexistente" do
      assert {:error, :invalid_credentials} = Accounts.authenticate_user("noexiste@test.com", "any")
    end
  end

  describe "authenticate_admin/2" do
    setup do
      {:ok, admin} = Accounts.register_user(valid_user_attrs(%{
        "email"    => "admin-auth@test.com",
        "password" => "Admin123!",
        "role"     => "admin"
      }))
      {:ok, user} = Accounts.register_user(valid_user_attrs(%{
        "email"    => "user-auth@test.com",
        "password" => "User123!"
      }))
      %{admin: admin, user: user}
    end

    test "autentica admin con credenciales correctas", %{admin: admin} do
      assert {:ok, a} = Accounts.authenticate_admin(admin.email, "Admin123!")
      assert a.role == "admin"
    end

    test "rechaza usuario sin rol admin", %{user: user} do
      assert {:error, :forbidden} = Accounts.authenticate_admin(user.email, "User123!")
    end

    test "rechaza password incorrecto", %{admin: admin} do
      assert {:error, :invalid_credentials} = Accounts.authenticate_admin(admin.email, "wrong")
    end
  end

  # helpers
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end
end
