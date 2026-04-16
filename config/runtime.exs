import Config

if config_env() == :prod do
  config :ms_backend, MsBackendWeb.Endpoint,
    http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT", "4000"))],
    secret_key_base: System.fetch_env!("SECRET_KEY_BASE")

  config :ms_backend, MsBackend.Repo,
    url: System.fetch_env!("DATABASE_URL"),
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))

  config :ms_backend,
    jwt_secret:    System.fetch_env!("JWT_SECRET"),
    resend_api_key: System.fetch_env!("RESEND_API_KEY"),
    resend_from:    System.get_env("RESEND_FROM", "noreply@loslibrosdivonnet.com"),
    frontend_url:  System.get_env("FRONTEND_URL", "https://loslibrosdivonnet.com"),
    admin_url:     System.get_env("ADMIN_URL", "https://admin.loslibrosdivonnet.com")
end
