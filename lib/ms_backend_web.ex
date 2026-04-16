defmodule MsBackendWeb do
  @moduledoc """
  Entrypoint para la interfaz web de MsBackend.
  """

  def controller do
    quote do
      use Phoenix.Controller, namespace: MsBackendWeb

      import Plug.Conn
      import MsBackendWeb.Gettext
      alias MsBackendWeb.Router.Helpers, as: Routes
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/ms_backend_web/templates",
        namespace: MsBackendWeb

      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

      import MsBackendWeb.ErrorHelpers
      import MsBackendWeb.Gettext
      alias MsBackendWeb.Router.Helpers, as: Routes
    end
  end

  def router do
    quote do
      use Phoenix.Router
      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      import MsBackendWeb.Gettext
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
