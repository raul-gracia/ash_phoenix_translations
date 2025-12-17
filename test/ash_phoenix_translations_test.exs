defmodule AshPhoenixTranslationsTest do
  @moduledoc """
  Core integration tests for AshPhoenixTranslations extension.

  This test module verifies the fundamental functionality of the AshPhoenixTranslations
  extension when applied to Ash resources. It covers extension configuration, DSL
  validation, and helper function behavior.

  ## Test Coverage

  ### Extension Structure
  - Extension loading and registration with Spark
  - Translatable attribute configuration (types, locales, options)
  - Backend selection (database vs gettext)
  - Cache TTL and audit configuration
  - Locale support and resource marking
  - Storage field name generation

  ### Helper Functions
  - `translate/2` with locale atoms and Plug.Conn
  - `translate_all/2` for batch resource translation
  - Locale extraction from connection assigns

  ### DSL Validation
  - Required locale validation (must be in supported locales)
  - Fallback locale validation (must be in supported locales)
  - Configuration error handling with Spark.Error.DslError

  ## Test Resource

  The `Product` test resource demonstrates a typical translation configuration:

      defmodule Product do
        use Ash.Resource,
          extensions: [AshPhoenixTranslations]

        translations do
          translatable_attribute :name, :string do
            locales [:en, :es, :fr]
            required [:en]
          end

          translatable_attribute :description, :text do
            locales [:en, :es, :fr]
            fallback(:en)
            markdown(true)
          end

          backend :database
          cache_ttl 3600
          audit_changes false
        end

        attributes do
          uuid_primary_key :id
          attribute :sku, :string
          attribute :price, :decimal
        end
      end

  ## Running Tests

      # Run all tests in this file
      mix test test/ash_phoenix_translations_test.exs

      # Run specific test
      mix test test/ash_phoenix_translations_test.exs:67

      # Run with detailed output
      mix test test/ash_phoenix_translations_test.exs --trace

  ## Key Patterns

  ### ETS Table Cleanup
  Tests use `setup` blocks to clean ETS tables before each test to ensure test isolation:

      setup do
        if :ets.whereis(:test_products) != :undefined do
          :ets.delete_all_objects(:test_products)
        end
        :ok
      end

  ### Resource Creation
  Tests create resources using Ash changesets and actions:

      {:ok, product} =
        Product
        |> Ash.Changeset.for_create(:create, %{
          sku: "TEST-001",
          price: Decimal.new("19.99"),
          name_translations: %{en: "English", es: "Español"}
        })
        |> Ash.create()

  ### Mock Plug.Conn
  Tests mock Plug.Conn structs for locale testing:

      conn = %Plug.Conn{
        assigns: %{locale: :es},
        private: %{}
      }

  ## Related Tests

  - `cache_test.exs` - ETS caching functionality
  - `transformers/` - Individual transformer behavior
  - `security/` - Atom exhaustion prevention
  - `graphql_test.exs` - GraphQL integration
  """
  # async: false because tests share ETS table :test_products
  use ExUnit.Case, async: false
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
        fallback(:en)
        markdown(true)
      end

      backend :database
      cache_ttl 3600
      audit_changes false
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
        require_atomic? false
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
    use Ash.Domain,
      validate_config_inclusion?: false

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
      # Clean ETS table before each test - only if it exists
      if :ets.whereis(:test_products) != :undefined do
        :ets.delete_all_objects(:test_products)
      end

      :ok
    end

    test "translate/2 with locale atom" do
      # Create a real product to test translation
      {:ok, product} =
        Product
        |> Ash.Changeset.for_create(:create, %{
          sku: "TEST-001",
          price: Decimal.new("19.99"),
          name_translations: %{en: "English", es: "Español"}
        })
        |> Ash.create()

      # Test with atom locale
      result = AshPhoenixTranslations.translate(product, :en)
      assert result.name == "English"
    end

    test "translate/2 with Plug.Conn" do
      {:ok, product} =
        Product
        |> Ash.Changeset.for_create(:create, %{
          sku: "TEST-002",
          price: Decimal.new("29.99"),
          name_translations: %{en: "English", es: "Español"}
        })
        |> Ash.create()

      # Mock a Plug.Conn with locale in assigns (not session)
      # The get_locale/1 function checks assigns first, so we don't need to fetch session
      conn = %Plug.Conn{
        assigns: %{locale: :es},
        private: %{}
      }

      result = AshPhoenixTranslations.translate(product, conn)
      assert result.name == "Español"
    end

    test "translate_all/2 with multiple resources" do
      {:ok, p1} =
        Product
        |> Ash.Changeset.for_create(:create, %{
          sku: "TEST-003",
          price: Decimal.new("39.99"),
          name_translations: %{en: "Product 1"}
        })
        |> Ash.create()

      {:ok, p2} =
        Product
        |> Ash.Changeset.for_create(:create, %{
          sku: "TEST-004",
          price: Decimal.new("49.99"),
          name_translations: %{en: "Product 2"}
        })
        |> Ash.create()

      results = AshPhoenixTranslations.translate_all([p1, p2], :en)
      assert length(results) == 2
      assert Enum.at(results, 0).name == "Product 1"
      assert Enum.at(results, 1).name == "Product 2"
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
              # fr is not in locales
              required [:fr]
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
              # fr is not in locales
              fallback(:fr)
            end
          end
        end
      end
    end
  end
end
