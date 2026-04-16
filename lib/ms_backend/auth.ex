defmodule MsBackend.Auth do
  @moduledoc "JWT auth helpers para ms_backend."

  @issuer "ms_backend"
  @ttl_hours 24

  def generate_token(user_id, role) do
    claims = %{
      "sub"  => user_id,
      "role" => role,
      "iss"  => @issuer,
      "iat"  => DateTime.utc_now() |> DateTime.to_unix(),
      "exp"  => DateTime.utc_now() |> DateTime.add(@ttl_hours * 3600, :second) |> DateTime.to_unix()
    }

    secret = Application.fetch_env!(:ms_backend, :jwt_secret)
    Joken.encode_and_sign(claims, Joken.Signer.create("HS256", secret))
  end

  def verify_token(token) do
    secret = Application.fetch_env!(:ms_backend, :jwt_secret)
    signer = Joken.Signer.create("HS256", secret)

    case Joken.verify(token, signer) do
      {:ok, claims} -> {:ok, claims}
      {:error, reason} -> {:error, reason}
    end
  end
end
