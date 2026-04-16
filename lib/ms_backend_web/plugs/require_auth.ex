defmodule MsBackendWeb.Plugs.RequireAuth do
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, claims}        <- MsBackend.Auth.verify_token(token) do
      conn
      |> assign(:current_user_id,   claims["sub"])
      |> assign(:current_user_role, claims["role"])
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "No autorizado"})
        |> halt()
    end
  end
end
