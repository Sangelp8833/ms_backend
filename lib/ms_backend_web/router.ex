defmodule MsBackendWeb.Router do
  use MsBackendWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug Corsica,
      origins: ["http://localhost:5174", "http://localhost:5175"],
      allow_headers: ["content-type", "authorization"],
      allow_methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
  end

  pipeline :authenticated do
    plug :accepts, ["json"]
    plug Corsica,
      origins: ["http://localhost:5174", "http://localhost:5175"],
      allow_headers: ["content-type", "authorization"],
      allow_methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
    plug MsBackendWeb.Plugs.RequireAuth
  end

  pipeline :admin_only do
    plug :accepts, ["json"]
    plug Corsica,
      origins: ["http://localhost:5175"],
      allow_headers: ["content-type", "authorization"],
      allow_methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
    plug MsBackendWeb.Plugs.RequireAuth
    plug MsBackendWeb.Plugs.RequireAdmin
  end

  # Auth público
  scope "/api/auth", MsBackendWeb do
    pipe_through :api
    post "/register",    AuthController, :register
    post "/login",       AuthController, :login
    post "/admin/login", AuthController, :admin_login
    delete "/logout",    AuthController, :logout
  end

  # Storefront — público
  scope "/api/storefront", MsBackendWeb do
    pipe_through :api
    get  "/products",       ProductController,  :index
    get  "/products/:id",   ProductController,  :show
    get  "/categories",     CategoryController, :index
    get  "/orders/:code",   OrderController,    :track
  end

  # Storefront — autenticado
  scope "/api/storefront", MsBackendWeb do
    pipe_through :authenticated
    post "/orders",          OrderController, :create
    get  "/orders",          OrderController, :my_orders
    get  "/me",              AuthController,  :me
  end

  # Admin — solo admins
  scope "/api/admin", MsBackendWeb do
    pipe_through :admin_only
    # Productos
    get    "/products",       ProductController, :admin_index
    post   "/products",       ProductController, :create
    put    "/products/:id",   ProductController, :update
    delete "/products/:id",   ProductController, :delete
    # Categorías
    post   "/categories",     CategoryController, :create
    put    "/categories/:id", CategoryController, :update
    delete "/categories/:id", CategoryController, :delete
    # Órdenes
    get  "/orders",           OrderController, :admin_index
    put  "/orders/:id/status", OrderController, :update_status
    # Estadísticas
    get  "/stats/sales",      StatsController, :sales
    get  "/stats/products",   StatsController, :top_products
    get  "/stats/monthly",    StatsController, :monthly
  end
end
