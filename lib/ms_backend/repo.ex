defmodule MsBackend.Repo do
  use Ecto.Repo,
    otp_app: :ms_backend,
    adapter: Ecto.Adapters.Postgres
end
