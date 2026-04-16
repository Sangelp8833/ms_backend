import Config

config :ms_backend, MsBackendWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: MsBackendWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: MsBackend.PubSub,
  live_view: [signing_salt: "LsIvN3t2025"]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :ms_backend, ecto_repos: [MsBackend.Repo]

config :phoenix, :json_library, Jason

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

import_config "#{config_env()}.exs"
