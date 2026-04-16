defmodule MsBackend.Accounts do
  import Ecto.Query
  alias MsBackend.Repo
  alias MsBackend.Accounts.User

  @doc "Registra un nuevo comprador."
  def register_user(attrs) do
    %User{}
    |> User.changeset(Map.put(attrs, "role", "user"))
    |> Repo.insert()
  end

  @doc "Autentica un comprador (role = user)."
  def authenticate_user(email, password) do
    user = Repo.get_by(User, email: String.downcase(email))
    verify_password(user, password, :any)
  end

  @doc "Autentica un admin (role = admin)."
  def authenticate_admin(email, password) do
    user = Repo.get_by(User, email: String.downcase(email))
    verify_password(user, password, :admin)
  end

  @doc "Busca un usuario por ID."
  def get_user(id) do
    Repo.get(User, id)
  end

  @doc "Busca un usuario por email."
  def get_user_by_email(email) do
    Repo.get_by(User, email: String.downcase(email))
  end

  # ── private ──────────────────────────────────────────────────

  defp verify_password(nil, _password, _role) do
    # Timing attack prevention
    Pbkdf2.no_user_verify()
    {:error, :invalid_credentials}
  end

  defp verify_password(user, password, :admin) do
    cond do
      not Pbkdf2.verify_pass(password, user.password_hash) ->
        {:error, :invalid_credentials}
      user.role != "admin" ->
        {:error, :forbidden}
      true ->
        {:ok, user}
    end
  end

  defp verify_password(user, password, :any) do
    if Pbkdf2.verify_pass(password, user.password_hash) do
      {:ok, user}
    else
      {:error, :invalid_credentials}
    end
  end
end
