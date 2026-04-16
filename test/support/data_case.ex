defmodule MsBackend.DataCase do
  @moduledoc """
  Test case for context modules. Checks out a sandbox DB connection
  and wraps each test in a transaction that's rolled back afterwards.
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      alias MsBackend.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import MsBackend.DataCase
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MsBackend.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(MsBackend.Repo, {:shared, self()})
    end

    :ok
  end

  # Helpers

  def valid_user_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        "name"     => "Test User",
        "email"    => "test#{System.unique_integer()}@example.com",
        "password" => "Password123!",
        "address"  => "Calle 1 #2-3"
      },
      overrides
    )
  end

  def valid_category_attrs(overrides \\ %{}) do
    Map.merge(%{"name" => "Categoría Test #{System.unique_integer()}"}, overrides)
  end

  def valid_product_attrs(category_id, overrides \\ %{}) do
    Map.merge(
      %{
        "name"        => "Producto Test #{System.unique_integer()}",
        "description" => "Descripción de prueba",
        "price"       => 10_000,
        "image_urls"  => ["https://example.com/img.jpg"],
        "category_id" => category_id,
        "type"        => "standard",
        "in_stock"    => true
      },
      overrides
    )
  end
end
