defmodule MsBackend.OrdersTest do
  use MsBackend.DataCase

  alias MsBackend.{Accounts, Catalog, Orders}
  alias MsBackend.Orders.Order

  setup do
    {:ok, user} = Accounts.register_user(valid_user_attrs())
    {:ok, cat}  = Catalog.create_category(valid_category_attrs())

    {:ok, p1} = Catalog.create_product(valid_product_attrs(cat.id, %{
      "name"  => "Libro A",
      "price" => 15_000
    }))
    {:ok, p2} = Catalog.create_product(valid_product_attrs(cat.id, %{
      "name"  => "Libro B",
      "price" => 10_000
    }))

    %{user: user, p1: p1, p2: p2}
  end

  describe "create_order/2" do
    test "crea orden con items válidos", %{user: user, p1: p1, p2: p2} do
      params = %{
        "address"        => "Calle 1 #2-3",
        "payment_method" => "transfer",
        "items" => [
          %{"product_id" => p1.id, "quantity" => 2},
          %{"product_id" => p2.id, "quantity" => 1}
        ]
      }

      assert {:ok, order} = Orders.create_order(user, params)
      assert order.total         == 2 * 15_000 + 10_000
      assert order.status        == "received"
      assert order.user_id       == user.id
      assert String.starts_with?(order.tracking_code, "LIV-")
      assert length(order.items) == 2
    end

    test "falla con producto inexistente", %{user: user} do
      params = %{
        "address" => "Calle 1",
        "items"   => [%{"product_id" => "00000000-0000-0000-0000-000000000000", "quantity" => 1}]
      }
      assert {:error, msgs} = Orders.create_order(user, params)
      assert is_list(msgs)
    end
  end

  describe "update_status/2" do
    setup %{user: user, p1: p1} do
      {:ok, order} = Orders.create_order(user, %{
        "address" => "Calle 1",
        "items"   => [%{"product_id" => p1.id, "quantity" => 1}]
      })
      %{order: order}
    end

    test "avanza al siguiente estado en secuencia", %{order: order} do
      assert order.status == "received"
      assert {:ok, o2} = Orders.update_status(order, "preparing")
      assert o2.status == "preparing"
      assert {:ok, o3} = Orders.update_status(o2, "shipped")
      assert o3.status == "shipped"
      assert {:ok, o4} = Orders.update_status(o3, "delivered")
      assert o4.status == "delivered"
    end

    test "falla si se intenta saltar un estado", %{order: order} do
      assert {:error, msg} = Orders.update_status(order, "shipped")
      assert msg =~ "preparing"
    end

    test "falla si la orden ya fue entregada", %{order: order} do
      {:ok, o2} = Orders.update_status(order, "preparing")
      {:ok, o3} = Orders.update_status(o2, "shipped")
      {:ok, o4} = Orders.update_status(o3, "delivered")
      assert {:error, msg} = Orders.update_status(o4, "delivered")
      assert msg =~ "entregada"
    end
  end

  describe "get_by_tracking_code/1" do
    setup %{user: user, p1: p1} do
      {:ok, order} = Orders.create_order(user, %{
        "address" => "Calle 1",
        "items"   => [%{"product_id" => p1.id, "quantity" => 1}]
      })
      %{order: order}
    end

    test "encuentra orden por tracking code", %{order: order} do
      found = Orders.get_by_tracking_code(order.tracking_code)
      assert found.id == order.id
    end

    test "devuelve nil si el código no existe" do
      assert is_nil(Orders.get_by_tracking_code("LIV-XXXXXX"))
    end
  end
end
