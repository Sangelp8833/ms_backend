defmodule MsBackend.Auth do
  @moduledoc "JWT helpers para ms_backend."

  @ttl_seconds 86_400  # 24 horas

  def generate_token(user_id, role) do
    secret = Application.fetch_env!(:ms_backend, :jwt_secret)
    now    = System.system_time(:second)

    claims = %{
      "sub"  => user_id,
      "role" => role,
      "iat"  => now,
      "exp"  => now + @ttl_seconds
    }

    signer = Joken.Signer.create("HS256", secret)
    Joken.encode_and_sign(claims, signer)
  end

  def verify_token(token) do
    secret = Application.fetch_env!(:ms_backend, :jwt_secret)
    signer = Joken.Signer.create("HS256", secret)

    case Joken.verify(token, signer) do
      {:ok, claims} ->
        now = System.system_time(:second)
        if claims["exp"] && claims["exp"] > now do
          {:ok, claims}
        else
          {:error, :expired}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
