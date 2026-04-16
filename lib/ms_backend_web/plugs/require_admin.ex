defmodule MsBackendWeb.Plugs.RequireAdmin do
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.assigns[:current_user_role] == "admin" do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Acceso restringido a administradores"})
      |> halt()
    end
  end
end
