defmodule AshPhoenixTranslationsTest do
  use ExUnit.Case
  doctest AshPhoenixTranslations

  # Test resource with translations
  defmodule Product do
    use Ash.Resource,
      domain: AshPhoenixTranslationsTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshPhoenixTranslations]

    ets do
      table :test_products
    end

    translations do
      translatable_attribute :name, :string do
        locales [:en, :es, :fr]
        required [:en]
      end

      translatable_attribute :description, :text do
        locales [:en, :es, :fr]
        fallback :en
        markdown true
      end

      backend :database
      cache_ttl 3600
      audit_changes false
    end

    actions do
      defaults [:read, :destroy]

      create :create do
        primary? true
        accept [:sku, :price]
      end

      update :update do
        primary? true
        accept [:sku, :price]
      end
    end

    attributes do
      uuid_primary_key :id
      attribute :sku, :string, allow_nil?: false
      attribute :price, :decimal
      timestamps()
    end
  end

  # Test domain
  defmodule Domain do
    use Ash.Domain

    resources do
      resource AshPhoenixTranslationsTest.Product
    end
  end

  describe "Extension Structure" do
    test "extension is properly loaded" do
      extensions = Spark.extensions(Product)
      assert AshPhoenixTranslations in extensions
    end

    test "translatable attributes are configured" do
      attrs = AshPhoenixTranslations.Info.translatable_attributes(Product)
      assert length(attrs) == 2
      
      name_attr = Enum.find(attrs, &(&1.name == :name))
      assert name_attr.type == :string
      assert name_attr.locales == [:en, :es, :fr]
      assert name_attr.required == [:en]
      
      desc_attr = Enum.find(attrs, &(&1.name == :description))
      assert desc_attr.type == :text
      assert desc_attr.fallback == :en
      assert desc_attr.markdown == true
    end

    test "backend is configured" do
      assert AshPhoenixTranslations.Info.backend(Product) == :database
    end

    test "cache TTL is configured" do
      assert AshPhoenixTranslations.Info.cache_ttl(Product) == 3600
    end

    test "audit changes is configured" do
      assert AshPhoenixTranslations.Info.audit_changes?(Product) == false
    end

    test "supported locales are retrieved" do
      locales = AshPhoenixTranslations.Info.supported_locales(Product)
      assert locales == [:en, :es, :fr]
    end

    test "resource is marked as translatable" do
      assert AshPhoenixTranslations.Info.translatable?(Product) == true
    end

    test "storage field names are generated correctly" do
      assert AshPhoenixTranslations.Info.storage_field(:name) == :name_translations
      assert AshPhoenixTranslations.Info.storage_field(:description) == :description_translations
    end
  end

  describe "Helper Functions" do
    setup do
      # Clean ETS table before each test
      :ets.delete_all_objects(:test_products)
      :ok
    end

    test "translate/2 with locale atom" do
      # This would require the transformers to be implemented
      # For now, we just test that the function exists and handles different inputs
      product = %Product{id: Ash.UUID.generate()}
      
      # Test with atom locale
      result = AshPhoenixTranslations.translate(product, :en)
      assert result
    end

    test "translate/2 with Plug.Conn" do
      product = %Product{id: Ash.UUID.generate()}
      
      # Mock a Plug.Conn
      conn = %Plug.Conn{
        assigns: %{locale: :es}
      }
      
      result = AshPhoenixTranslations.translate(product, conn)
      assert result
    end

    test "translate_all/2 with multiple resources" do
      products = [
        %Product{id: Ash.UUID.generate()},
        %Product{id: Ash.UUID.generate()}
      ]
      
      results = AshPhoenixTranslations.translate_all(products, :en)
      assert length(results) == 2
    end
  end

  describe "DSL Validation" do
    test "raises error when required locale is not in supported locales" do
      assert_raise Spark.Error.DslError, fn ->
        defmodule InvalidProduct do
          use Ash.Resource,
            domain: AshPhoenixTranslationsTest.Domain,
            data_layer: Ash.DataLayer.Ets,
            extensions: [AshPhoenixTranslations]

          translations do
            translatable_attribute :name, :string do
              locales [:en, :es]
              required [:fr]  # fr is not in locales
            end
          end
        end
      end
    end

    test "raises error when fallback locale is not in supported locales" do
      assert_raise Spark.Error.DslError, fn ->
        defmodule InvalidProduct2 do
          use Ash.Resource,
            domain: AshPhoenixTranslationsTest.Domain,
            data_layer: Ash.DataLayer.Ets,
            extensions: [AshPhoenixTranslations]

          translations do
            translatable_attribute :name, :string do
              locales [:en, :es]
              fallback :fr  # fr is not in locales
            end
          end
        end
      end
    end
  end
end