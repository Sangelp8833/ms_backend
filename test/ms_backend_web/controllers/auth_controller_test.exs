defmodule MsBackendWeb.AuthControllerTest do
  use MsBackendWeb.ConnCase

  alias MsBackend.Accounts

  @register_path "/api/auth/register"
  @login_path    "/api/auth/login"
  @me_path       "/api/auth/me"

  describe "POST /api/auth/register" do
    test "registra usuario y devuelve token", %{conn: conn} do
      params = %{
        name:     "Test User",
        email:    "reg#{System.unique_integer()}@test.com",
        password: "Password123!",
        address:  "Calle 1"
      }

      conn = post(conn, @register_path, params)
      assert %{"token" => token, "user" => user} = json_response(conn, 201)
      assert is_binary(token)
      assert user["email"] == params.email
      assert user["role"]  == "user"
    end

    test "falla con email duplicado", %{conn: conn} do
      email = "dup#{System.unique_integer()}@test.com"
      params = %{name: "A", email: email, password: "Password123!", address: "X"}

      post(conn, @register_path, params)
      conn2 = post(build_conn(), @register_path, params)
      assert %{"errors" => _} = json_response(conn2, 422)
    end
  end

  describe "POST /api/auth/login" do
    setup do
      email    = "login#{System.unique_integer()}@test.com"
      password = "Password123!"
      {:ok, user} = Accounts.register_user(%{"name" => "L", "email" => email, "password" => password, "address" => "X"})
      %{email: email, password: password, user: user}
    end

    test "autentica y devuelve token", %{conn: conn, email: email, password: password} do
      conn = post(conn, @login_path, %{email: email, password: password})
      assert %{"token" => token} = json_response(conn, 200)
      assert is_binary(token)
    end

    test "falla con contraseña incorrecta", %{conn: conn, email: email} do
      conn = post(conn, @login_path, %{email: email, password: "wrong"})
      assert %{"error" => _} = json_response(conn, 401)
    end
  end

  describe "GET /api/auth/me" do
    test "devuelve usuario autenticado", %{conn: conn} do
      email = "me#{System.unique_integer()}@test.com"
      {:ok, user} = Accounts.register_user(%{"name" => "Me", "email" => email, "password" => "Password123!", "address" => "X"})
      {:ok, token, _} = MsBackend.Auth.generate_token(user.id, user.role)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(@me_path)

      assert %{"user" => me} = json_response(conn, 200)
      assert me["id"] == user.id
    end

    test "rechaza sin token", %{conn: conn} do
      conn = get(conn, @me_path)
      assert json_response(conn, 401)
    end
  end
end
