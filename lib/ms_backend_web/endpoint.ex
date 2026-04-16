defmodule MsBackendWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :ms_backend

  @session_options [
    store: :cookie,
    key: "_ms_backend_key",
    signing_salt: "LsIvN3t!"
  ]

  plug Plug.Static,
    at: "/",
    from: :ms_backend,
    gzip: false,
    only: ~w(assets fonts images favicon.ico robots.txt)

  if code_reloading? do
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug MsBackendWeb.Router
end
