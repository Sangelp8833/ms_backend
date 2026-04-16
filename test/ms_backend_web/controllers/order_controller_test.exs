defmodule MsBackendWeb.OrderControllerTest do
  use MsBackendWeb.ConnCase

  alias MsBackend.{Accounts, Catalog, Orders}

  setup do
    {:ok, admin} = Accounts.register_user(%{
      "name"     => "Admin",
      "email"    => "admin#{System.unique_integer()}@test.com",
      "password" => "Admin123!",
      "address"  => "Calle Admin",
      "role"     => "admin"
    })
    {:ok, admin_token, _} = MsBackend.Auth.generate_token(admin.id, admin.role)

    {:ok, user} = Accounts.register_user(%{
      "name"     => "Comprador",
      "email"    => "buyer#{System.unique_integer()}@test.com",
      "password" => "Buyer123!",
      "address"  => "Calle Comprador"
    })
    {:ok, user_token, _} = MsBackend.Auth.generate_token(user.id, user.role)

    {:ok, cat} = Catalog.create_category(%{"name" => "OrdCat #{System.unique_integer()}"})
    {:ok, product} = Catalog.create_product(%{
      "name"        => "Producto Orden",
      "description" => "desc",
      "price"       => 20_000,
      "image_urls"  => ["https://example.com/img.jpg"],
      "category_id" => cat.id,
      "type"        => "standard",
      "in_stock"    => true
    })

    %{admin: admin, admin_token: admin_token,
      user: user, user_token: user_token,
      product: product}
  end

  describe "POST /api/storefront/orders" do
    test "usuario autenticado puede crear orden", %{conn: conn, user_token: token, product: p} do
      params = %{
        address:        "Calle 1",
        payment_method: "transfer",
        items:          [%{product_id: p.id, quantity: 2}]
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post("/api/storefront/orders", params)

      assert %{"order" => order} = json_response(conn, 201)
      assert order["status"]        == "received"
      assert order["total"]         == 40_000
      assert String.starts_with?(order["tracking_code"], "LIV-")
    end

    test "falla sin autenticación", %{conn: conn, product: p} do
      params = %{address: "X", items: [%{product_id: p.id, quantity: 1}]}
      conn = post(conn, "/api/storefront/orders", params)
      assert json_response(conn, 401)
    end
  end

  describe "GET /api/storefront/orders/:code" do
    test "tracking público funciona sin auth", %{conn: conn, user: user, product: p} do
      {:ok, order} = Orders.create_order(user, %{
        "address" => "X",
        "items"   => [%{"product_id" => p.id, "quantity" => 1}]
      })

      conn = get(conn, "/api/storefront/orders/#{order.tracking_code}")
      assert %{"order" => info} = json_response(conn, 200)
      assert info["tracking_code"] == order.tracking_code
      assert info["status"]        == "received"
    end

    test "devuelve 404 si código no existe", %{conn: conn} do
      conn = get(conn, "/api/storefront/orders/LIV-ZZZZZZ")
      assert json_response(conn, 404)
    end
  end

  describe "GET /api/admin/orders" do
    test "admin puede listar todas las órdenes", %{conn: conn, admin_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/admin/orders")

      assert %{"data" => _, "meta" => _} = json_response(conn, 200)
    end

    test "usuario sin admin recibe 403", %{conn: conn, user_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/admin/orders")

      assert json_response(conn, 403)
    end
  end

  describe "PUT /api/admin/orders/:id/status" do
    test "admin avanza el estado de una orden", %{conn: conn, admin_token: token, user: user, product: p} do
      {:ok, order} = Orders.create_order(user, %{
        "address" => "X",
        "items"   => [%{"product_id" => p.id, "quantity" => 1}]
      })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put("/api/admin/orders/#{order.id}/status", %{status: "preparing"})

      assert %{"order" => updated} = json_response(conn, 200)
      assert updated["status"] == "preparing"
    end

    test "falla si el estado no es el siguiente válido", %{conn: conn, admin_token: token, user: user, product: p} do
      {:ok, order} = Orders.create_order(user, %{
        "address" => "X",
        "items"   => [%{"product_id" => p.id, "quantity" => 1}]
      })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put("/api/admin/orders/#{order.id}/status", %{status: "delivered"})

      assert %{"error" => _} = json_response(conn, 422)
    end
  end
end
