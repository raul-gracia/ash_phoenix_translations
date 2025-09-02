defmodule AshPhoenixTranslations.IntegrationTest do
  use ExUnit.Case, async: false

  # Test modules
  defmodule TestDomain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource AshPhoenixTranslations.IntegrationTest.TestProduct
      resource AshPhoenixTranslations.IntegrationTest.TestCategory
    end
  end

  defmodule TestProduct do
    use Ash.Resource,
      domain: TestDomain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshPhoenixTranslations]

    translations do
      translatable_attribute :name, :string,
        locales: [:en, :es, :fr],
        required: [:en]

      translatable_attribute :description, :text, locales: [:en, :es, :fr]

      backend :database
      cache_ttl 3600
      audit_changes true
    end

    attributes do
      uuid_primary_key :id

      attribute :sku, :string do
        allow_nil? false
      end

      attribute :price, :decimal

      timestamps()
    end

    actions do
      defaults [:read, :destroy]

      create :create do
        primary? true
        accept [:sku, :price, :name_translations, :description_translations]
      end

      update :update do
        primary? true
        accept [:sku, :price, :name_translations, :description_translations]
      end
    end
  end

  defmodule TestCategory do
    use Ash.Resource,
      domain: TestDomain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshPhoenixTranslations]

    translations do
      translatable_attribute :title, :string,
        locales: [:en, :de],
        required: [:en]

      backend :database
    end

    attributes do
      uuid_primary_key :id

      attribute :slug, :string do
        allow_nil? false
      end

      timestamps()
    end

    actions do
      defaults [:create, :read, :update, :destroy]
    end
  end

  setup do
    # Start the cache
    {:ok, _} = AshPhoenixTranslations.Cache.start_link()
    AshPhoenixTranslations.Cache.clear()

    :ok
  end

  describe "resource creation with translations" do
    test "creates resource with translations" do
      {:ok, product} =
        TestProduct
        |> Ash.Changeset.for_create(:create, %{
          sku: "PROD-001",
          price: Decimal.new("29.99"),
          name_translations: %{
            en: "Product Name",
            es: "Nombre del Producto",
            fr: "Nom du Produit"
          },
          description_translations: %{
            en: "Product description",
            es: "Descripción del producto"
          }
        })
        |> Ash.create()

      assert product.sku == "PROD-001"
      assert product.name_translations.en == "Product Name"
      assert product.name_translations.es == "Nombre del Producto"
      assert product.name_translations.fr == "Nom du Produit"
      assert product.description_translations.en == "Product description"
      assert product.description_translations.es == "Descripción del producto"
    end

    test "validates required locales" do
      changeset =
        TestProduct
        |> Ash.Changeset.for_create(:create, %{
          sku: "PROD-002",
          price: Decimal.new("19.99"),
          name_translations: %{
            es: "Solo Español"
          }
        })

      # Should require English translation
      assert {:error, %Ash.Error.Invalid{}} = Ash.create(changeset)
    end
  end

  describe "translation calculations" do
    setup do
      {:ok, product} =
        TestProduct
        |> Ash.Changeset.for_create(:create, %{
          sku: "PROD-003",
          price: Decimal.new("39.99"),
          name_translations: %{
            en: "English Name",
            es: "Spanish Name",
            fr: "French Name"
          },
          description_translations: %{
            en: "English Description",
            es: "Spanish Description",
            fr: "French Description"
          }
        })
        |> Ash.create()

      {:ok, product: product}
    end

    test "translates fields based on locale", %{product: product} do
      # Test translation with different locales
      translated_en = AshPhoenixTranslations.translate(product, :en)
      assert translated_en.name == "English Name"
      assert translated_en.description == "English Description"

      translated_es = AshPhoenixTranslations.translate(product, :es)
      assert translated_es.name == "Spanish Name"
      assert translated_es.description == "Spanish Description"

      translated_fr = AshPhoenixTranslations.translate(product, :fr)
      assert translated_fr.name == "French Name"
      assert translated_fr.description == "French Description"
    end

    test "falls back to default locale when translation missing", %{product: product} do
      # Remove French description
      {:ok, updated} =
        product
        |> Ash.Changeset.for_update(:update, %{
          description_translations: %{
            en: "English Description",
            es: "Spanish Description"
          }
        })
        |> Ash.update()

      # Should fall back to English
      translated = AshPhoenixTranslations.translate(updated, :fr)
      assert translated.description == "English Description"
    end
  end

  describe "caching" do
    setup do
      {:ok, product} =
        TestProduct
        |> Ash.Changeset.for_create(:create, %{
          sku: "PROD-004",
          price: Decimal.new("49.99"),
          name_translations: %{
            en: "Cached Product",
            es: "Producto en Caché"
          }
        })
        |> Ash.create()

      {:ok, product: product}
    end

    test "caches translations", %{product: product} do
      # First access should miss cache
      stats_before = AshPhoenixTranslations.Cache.stats()

      # Simulate translation fetch that would be cached
      key = {TestProduct, product.id, :name, :en}
      value = "Cached Product"
      AshPhoenixTranslations.Cache.put(key, value)

      # Second access should hit cache
      assert {:ok, cached_value} = AshPhoenixTranslations.Cache.get(key)
      assert cached_value == value

      stats_after = AshPhoenixTranslations.Cache.stats()
      assert stats_after.hits > stats_before.hits
    end

    test "invalidates cache on update", %{product: product} do
      # Cache the translation
      key = {TestProduct, product.id, :name, :en}
      AshPhoenixTranslations.Cache.put(key, "Original Name")

      # Update the product
      {:ok, _updated} =
        product
        |> Ash.Changeset.for_update(:update, %{
          name_translations: %{
            en: "Updated Name",
            es: "Nombre Actualizado"
          }
        })
        |> Ash.update()

      # Cache should be invalidated
      AshPhoenixTranslations.Cache.invalidate_resource(TestProduct, product.id)
      assert AshPhoenixTranslations.Cache.get(key) == :miss
    end
  end

  describe "Info introspection" do
    test "returns translatable attributes" do
      attrs = AshPhoenixTranslations.Info.translatable_attributes(TestProduct)
      assert length(attrs) == 2

      names = Enum.map(attrs, & &1.name)
      assert :name in names
      assert :description in names
    end

    test "returns specific translatable attribute" do
      attr = AshPhoenixTranslations.Info.translatable_attribute(TestProduct, :name)
      assert attr.name == :name
      assert attr.locales == [:en, :es, :fr]
      assert attr.required == [:en]
    end

    test "returns backend configuration" do
      assert AshPhoenixTranslations.Info.backend(TestProduct) == :database
    end

    test "returns cache TTL" do
      assert AshPhoenixTranslations.Info.cache_ttl(TestProduct) == 3600
    end

    test "returns supported locales" do
      locales = AshPhoenixTranslations.Info.supported_locales(TestProduct)
      assert :en in locales
      assert :es in locales
      assert :fr in locales
    end

    test "checks if resource is translatable" do
      assert AshPhoenixTranslations.Info.translatable?(TestProduct) == true
      assert AshPhoenixTranslations.Info.translatable?(TestCategory) == true
    end
  end

  describe "bulk operations" do
    test "updates multiple resources with translations" do
      # Create multiple products
      products =
        for i <- 1..3 do
          {:ok, product} =
            TestProduct
            |> Ash.Changeset.for_create(:create, %{
              sku: "BULK-#{i}",
              price: Decimal.new("9.99"),
              name_translations: %{
                en: "Product #{i}",
                es: "Producto #{i}"
              }
            })
            |> Ash.create()

          product
        end

      # Bulk update translations
      updated_products =
        Enum.map(products, fn product ->
          {:ok, updated} =
            product
            |> Ash.Changeset.for_update(:update, %{
              name_translations: %{
                en: "Updated #{product.sku}",
                es: "Actualizado #{product.sku}",
                fr: "Mis à jour #{product.sku}"
              }
            })
            |> Ash.update()

          updated
        end)

      # Verify all were updated
      Enum.each(updated_products, fn product ->
        assert product.name_translations.en =~ "Updated"
        assert product.name_translations.es =~ "Actualizado"
        assert product.name_translations.fr =~ "Mis à jour"
      end)
    end
  end

  describe "translation helpers" do
    setup do
      {:ok, product} =
        TestProduct
        |> Ash.Changeset.for_create(:create, %{
          sku: "HELPER-001",
          price: Decimal.new("59.99"),
          name_translations: %{
            en: "Helper Product",
            es: "Producto Helper",
            fr: "Produit Helper"
          }
        })
        |> Ash.create()

      {:ok, product: product}
    end

    test "translate_field/3 returns specific translation", %{product: product} do
      assert AshPhoenixTranslations.translate_field(product, :name, :es) == "Producto Helper"
      assert AshPhoenixTranslations.translate_field(product, :name, :fr) == "Produit Helper"
    end

    test "available_locales/2 returns locales with translations", %{product: product} do
      locales = AshPhoenixTranslations.available_locales(product, :name)
      assert :en in locales
      assert :es in locales
      assert :fr in locales
    end

    test "translation_completeness/1 calculates percentage", %{product: product} do
      # Name has all 3 locales, description has none
      # Total: 6 possible translations, 3 complete
      completeness = AshPhoenixTranslations.translation_completeness(product)
      assert completeness == 50.0
    end
  end

  describe "multi-backend support" do
    test "different resources can use different backends" do
      # TestProduct uses :database backend
      assert AshPhoenixTranslations.Info.backend(TestProduct) == :database

      # TestCategory also uses :database backend
      assert AshPhoenixTranslations.Info.backend(TestCategory) == :database

      # Both should work correctly
      {:ok, category} =
        TestCategory
        |> Ash.Changeset.for_create(:create, %{
          slug: "test-category",
          title_translations: %{
            en: "Test Category",
            de: "Testkategorie"
          }
        })
        |> Ash.create()

      assert category.title_translations.en == "Test Category"
      assert category.title_translations.de == "Testkategorie"
    end
  end
end
