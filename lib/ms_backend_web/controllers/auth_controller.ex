defmodule MsBackendWeb.AuthController do
  use MsBackendWeb, :controller

  alias MsBackend.Accounts
  alias MsBackend.Auth

  # POST /api/auth/register
  def register(conn, params) do
    attrs = %{
      "name"     => params["name"],
      "email"    => params["email"],
      "password" => params["password"],
      "address"  => params["address"]
    }

    case Accounts.register_user(attrs) do
      {:ok, user} ->
        {:ok, token, _claims} = Auth.generate_token(user.id, user.role)

        conn
        |> put_status(:created)
        |> json(%{
          token: token,
          user: user_json(user)
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  # POST /api/auth/login
  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        {:ok, token, _claims} = Auth.generate_token(user.id, user.role)
        json(conn, %{token: token, user: user_json(user)})

      {:error, :invalid_credentials} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Email o contraseña incorrectos"})
    end
  end

  # POST /api/auth/admin/login
  def admin_login(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_admin(email, password) do
      {:ok, user} ->
        {:ok, token, _claims} = Auth.generate_token(user.id, user.role)
        json(conn, %{token: token, admin: user_json(user)})

      {:error, :invalid_credentials} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Email o contraseña incorrectos"})

      {:error, :forbidden} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "No tienes permisos de administrador"})
    end
  end

  # DELETE /api/auth/logout
  def logout(conn, _params) do
    json(conn, %{ok: true})
  end

  # GET /api/auth/me
  def me(conn, _params) do
    user = Accounts.get_user(conn.assigns.current_user_id)

    case user do
      nil  -> conn |> put_status(:not_found) |> json(%{error: "Usuario no encontrado"})
      user -> json(conn, %{user: user_json(user)})
    end
  end

  # ── helpers ──────────────────────────────────────────────────

  defp user_json(user) do
    %{
      id:      user.id,
      name:    user.name,
      email:   user.email,
      address: user.address,
      role:    user.role
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
