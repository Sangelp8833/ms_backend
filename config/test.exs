import Config

config :ms_backend, MsBackendWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  secret_key_base: "TEST_SECRET_KEY_BASE_LosLibrosDeIvonnet_32chars_test_only!!!!!",
  server: false

config :ms_backend, MsBackend.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "los_libros_de_ivonnet_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :logger, level: :warn
config :phoenix, :plug_init_mode, :runtime
