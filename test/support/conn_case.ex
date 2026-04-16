defmodule MsBackendWeb.ConnCase do
  @moduledoc """
  Test case for controllers. Sets up a Plug.Test connection and
  checks out a sandbox DB connection for each test.
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      import MsBackendWeb.ConnCase

      alias MsBackendWeb.Router.Helpers, as: Routes

      @endpoint MsBackendWeb.Endpoint
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MsBackend.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(MsBackend.Repo, {:shared, self()})
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
