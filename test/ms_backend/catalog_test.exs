defmodule MsBackend.CatalogTest do
  use MsBackend.DataCase

  alias MsBackend.Catalog
  alias MsBackend.Catalog.{Category, Product}

  # ── Categorías ────────────────────────────────────────────────

  describe "create_category/1" do
    test "crea categoría con nombre válido" do
      assert {:ok, %Category{} = cat} = Catalog.create_category(valid_category_attrs())
      assert cat.slug =~ ~r/^[a-z0-9-]+$/
    end

    test "genera slug desde nombre" do
      assert {:ok, cat} = Catalog.create_category(%{"name" => "Kits de Libros"})
      assert cat.slug == "kits-de-libros"
    end

    test "acepta slug personalizado" do
      assert {:ok, cat} = Catalog.create_category(%{"name" => "X", "slug" => "mi-slug"})
      assert cat.slug == "mi-slug"
    end

    test "falla con slug duplicado" do
      {:ok, _} = Catalog.create_category(%{"name" => "Original", "slug" => "slug-dupl"})
      assert {:error, changeset} = Catalog.create_category(%{"name" => "Otro", "slug" => "slug-dupl"})
      assert %{slug: _} = errors_on(changeset)
    end
  end

  describe "list_categories/0" do
    test "devuelve todas las categorías" do
      {:ok, _} = Catalog.create_category(valid_category_attrs())
      {:ok, _} = Catalog.create_category(valid_category_attrs())
      cats = Catalog.list_categories()
      assert length(cats) >= 2
    end
  end

  # ── Productos ─────────────────────────────────────────────────

  describe "create_product/1" do
    setup do
      {:ok, cat} = Catalog.create_category(valid_category_attrs())
      %{category: cat}
    end

    test "crea producto estándar", %{category: cat} do
      assert {:ok, %Product{} = p} = Catalog.create_product(valid_product_attrs(cat.id))
      assert p.type == "standard"
      assert is_nil(p.deleted_at)
    end

    test "crea producto sponsored con campos de sponsor", %{category: cat} do
      attrs = valid_product_attrs(cat.id, %{
        "type"            => "sponsored",
        "sponsor_name"    => "Librería Test",
        "sponsor_logo"    => "https://example.com/logo.png",
        "sponsor_tagline" => "Tagline de prueba"
      })
      assert {:ok, p} = Catalog.create_product(attrs)
      assert p.type          == "sponsored"
      assert p.sponsor_name  == "Librería Test"
    end

    test "falla si sponsored sin sponsor_name", %{category: cat} do
      attrs = valid_product_attrs(cat.id, %{"type" => "sponsored"})
      assert {:error, changeset} = Catalog.create_product(attrs)
      assert %{sponsor_name: _} = errors_on(changeset)
    end

    test "falla sin categoría válida" do
      attrs = valid_product_attrs("00000000-0000-0000-0000-000000000000")
      assert {:error, _} = Catalog.create_product(attrs)
    end
  end

  describe "list_products/1" do
    setup do
      {:ok, cat1} = Catalog.create_category(valid_category_attrs())
      {:ok, cat2} = Catalog.create_category(valid_category_attrs())
      {:ok, p1}   = Catalog.create_product(valid_product_attrs(cat1.id))
      {:ok, p2}   = Catalog.create_product(valid_product_attrs(cat2.id))
      {:ok, p3}   = Catalog.create_product(valid_product_attrs(cat1.id))
      %{cat1: cat1, cat2: cat2, p1: p1, p2: p2, p3: p3}
    end

    test "lista todos los productos activos", %{p1: p1, p2: p2, p3: p3} do
      result = Catalog.list_products([])
      ids = Enum.map(result.data, & &1.id)
      assert p1.id in ids
      assert p2.id in ids
      assert p3.id in ids
    end

    test "filtra por categoría", %{cat1: cat1, p1: p1, p2: p2, p3: p3} do
      result = Catalog.list_products(category_id: cat1.id)
      ids = Enum.map(result.data, & &1.id)
      assert p1.id in ids
      assert p3.id in ids
      refute p2.id in ids
    end

    test "no incluye productos eliminados", %{p1: p1} do
      {:ok, _} = Catalog.soft_delete_product(p1)
      result = Catalog.list_products([])
      ids = Enum.map(result.data, & &1.id)
      refute p1.id in ids
    end
  end

  describe "soft_delete_product/1" do
    setup do
      {:ok, cat} = Catalog.create_category(valid_category_attrs())
      {:ok, p}   = Catalog.create_product(valid_product_attrs(cat.id))
      %{product: p}
    end

    test "hace soft delete", %{product: p} do
      assert {:ok, deleted} = Catalog.soft_delete_product(p)
      assert not is_nil(deleted.deleted_at)
    end

    test "no incluye producto borrado en list_products", %{product: p} do
      {:ok, _} = Catalog.soft_delete_product(p)
      result = Catalog.list_products([])
      ids = Enum.map(result.data, & &1.id)
      refute p.id in ids
    end
  end

  # helpers
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end
end
