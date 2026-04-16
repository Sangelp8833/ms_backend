import Config

config :ms_backend, MsBackendWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "LosLibrosDeIvonnet_DEV_SECRET_KEY_BASE_CHANGE_IN_PROD_32chars+",
  watchers: []

config :ms_backend, MsBackend.Repo,
  username: "postgres",
  password: "Cocoliso3388*",
  hostname: "localhost",
  port: 5432,
  database: "los_libros_de_ivonnet_dev",
  show_sensitive_data_on_connection_error: true,
  pool_size: 15

config :ms_backend,
  jwt_secret: "dev_jwt_secret_change_in_prod",
  resend_api_key: "re_CHANGEME",
  resend_from: "onboarding@resend.dev",
  frontend_url: "http://localhost:5174",
  admin_url: "http://localhost:5175",
  mailer_enabled: true,
  log_level: :debug

config :logger, :console, format: "[$level] $message\n"
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
