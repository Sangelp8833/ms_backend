defmodule MsBackendWeb.ProductControllerTest do
  use MsBackendWeb.ConnCase

  alias MsBackend.{Accounts, Catalog}

  setup do
    {:ok, admin} = Accounts.register_user(%{
      "name"     => "Admin",
      "email"    => "admin#{System.unique_integer()}@test.com",
      "password" => "Admin123!",
      "address"  => "X",
      "role"     => "admin"
    })
    {:ok, admin_token, _} = MsBackend.Auth.generate_token(admin.id, admin.role)

    {:ok, user} = Accounts.register_user(%{
      "name"     => "User",
      "email"    => "user#{System.unique_integer()}@test.com",
      "password" => "User123!",
      "address"  => "X"
    })
    {:ok, user_token, _} = MsBackend.Auth.generate_token(user.id, user.role)

    {:ok, cat} = Catalog.create_category(%{"name" => "Cat Test #{System.unique_integer()}"})

    %{admin_token: admin_token, user_token: user_token, category: cat}
  end

  describe "GET /api/storefront/products" do
    test "lista productos públicamente sin auth", %{conn: conn, category: cat} do
      {:ok, _} = Catalog.create_product(%{
        "name" => "Público", "description" => "desc",
        "price" => 1000, "image_urls" => [], "category_id" => cat.id,
        "type" => "standard", "in_stock" => true
      })
      conn = get(conn, "/api/storefront/products")
      assert %{"data" => _, "meta" => _} = json_response(conn, 200)
    end
  end

  describe "POST /api/admin/products" do
    test "admin puede crear producto", %{conn: conn, admin_token: token, category: cat} do
      params = %{
        name: "Nuevo Libro", description: "desc",
        price: 12_000, image_urls: [], category_id: cat.id,
        type: "standard", in_stock: true
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post("/api/admin/products", params)

      assert %{"data" => p} = json_response(conn, 201)
      assert p["name"] == "Nuevo Libro"
    end

    test "usuario sin admin recibe 403", %{conn: conn, user_token: token, category: cat} do
      params = %{name: "X", description: "d", price: 1, image_urls: [], category_id: cat.id, type: "standard"}

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post("/api/admin/products", params)

      assert json_response(conn, 403)
    end

    test "sin token recibe 401", %{conn: conn, category: cat} do
      params = %{name: "X", description: "d", price: 1, image_urls: [], category_id: cat.id, type: "standard"}
      conn = post(conn, "/api/admin/products", params)
      assert json_response(conn, 401)
    end
  end

  describe "DELETE /api/admin/products/:id" do
    test "admin puede eliminar producto", %{conn: conn, admin_token: token, category: cat} do
      {:ok, p} = Catalog.create_product(%{
        "name" => "Del", "description" => "d", "price" => 1000,
        "image_urls" => [], "category_id" => cat.id, "type" => "standard", "in_stock" => true
      })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> delete("/api/admin/products/#{p.id}")

      assert json_response(conn, 200)
    end
  end
end
