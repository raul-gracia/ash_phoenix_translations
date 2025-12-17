defmodule AshPhoenixTranslations.InfoTest do
  @moduledoc """
  Comprehensive tests for the Info introspection module.

  This module tests the introspection functions that retrieve translation
  configuration and metadata from resources using the AshPhoenixTranslations
  extension.

  ## Test Coverage

  ### Translatable Attributes
  - Retrieving all translatable attributes from a resource
  - Getting specific attributes by name
  - Handling resources without translatable attributes
  - Checking if a resource is translatable

  ### Supported Locales
  - Getting all supported locales across attributes
  - Deduplication of locales
  - Sorting of locales
  - Empty list for non-translatable resources

  ### Backend Configuration
  - Database backend configuration
  - Gettext backend configuration
  - Default backend when not specified

  ### Cache Configuration
  - Custom cache TTL values
  - Default TTL when not specified

  ### Audit Configuration
  - Audit changes enabled
  - Audit changes disabled (default)
  - Auto-validation enabled (default)
  - Auto-validation disabled

  ### Field Name Generators
  - Storage field name generation
  - All translations field name generation

  ### Policy Configuration
  - View policies (public, admin, custom)
  - Edit policies (admin, custom)
  - Approval policies
  - Default policy values

  ## Test Resources

  Three test resources are defined:

  1. **ProductResource**: Full translation configuration with database backend
  2. **CategoryResource**: Minimal configuration with gettext backend
  3. **NonTranslatableResource**: Resource without translations

  ## Running Tests

      # Run all info tests
      mix test test/info_test.exs

      # Run specific test group
      mix test test/info_test.exs --only describe:"translatable_attributes/1"

      # Run with detailed trace
      mix test test/info_test.exs --trace

  ## Key Patterns

  ### Resource Definition
  Test resources are defined inline to avoid compilation order issues:

      defmodule TestResource do
        use Ash.Resource,
          extensions: [AshPhoenixTranslations]

        translations do
          translatable_attribute :name, :string, locales: [:en, :es]
          backend :database
        end
      end

  ### Introspection Testing
  Tests use the Info module functions to verify configuration:

      assert Info.translatable?(ProductResource)
      assert Info.backend(ProductResource) == :database
      assert Info.supported_locales(ProductResource) == [:en, :es, :fr]
  """
  use ExUnit.Case, async: true

  alias AshPhoenixTranslations.Info

  # Test resource with comprehensive translation configuration
  defmodule ProductResource do
    @moduledoc false
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshPhoenixTranslations]

    translations do
      translatable_attribute :name, :string,
        locales: [:en, :es, :fr],
        required: [:en]

      translatable_attribute :description, :text,
        locales: [:en, :es, :fr, :de],
        fallback: :en

      translatable_attribute :tagline, :string,
        locales: [:en, :es],
        markdown: true

      backend :database
      cache_ttl 7200
      audit_changes true
      auto_validate false
    end

    attributes do
      uuid_primary_key :id
      attribute :sku, :string, allow_nil?: false
    end

    actions do
      defaults [:read, :create, :update, :destroy]
    end
  end

  # Test resource with minimal configuration
  defmodule CategoryResource do
    @moduledoc false
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshPhoenixTranslations]

    translations do
      translatable_attribute :title, :string, locales: [:en, :de]

      backend :gettext
    end

    attributes do
      uuid_primary_key :id
      attribute :slug, :string, allow_nil?: false
    end

    actions do
      defaults [:read, :create, :update, :destroy]
    end
  end

  # Test resource with policy configuration
  defmodule PolicyResource do
    @moduledoc false
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshPhoenixTranslations]

    translations do
      translatable_attribute :content, :text, locales: [:en, :es]

      backend :database

      policy view: :admin,
             edit: {:role, [:translator]},
             approval: [approvers: [:admin], required_for: [:production]]
    end

    attributes do
      uuid_primary_key :id
    end

    actions do
      defaults [:read, :create, :update, :destroy]
    end
  end

  # Test resource without translations
  defmodule NonTranslatableResource do
    @moduledoc false
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Ets

    attributes do
      uuid_primary_key :id
      attribute :name, :string, allow_nil?: false
    end

    actions do
      defaults [:read, :create, :update, :destroy]
    end
  end

  describe "translatable_attributes/1" do
    test "returns all translatable attributes for a resource" do
      attrs = Info.translatable_attributes(ProductResource)

      assert length(attrs) == 3
      assert Enum.any?(attrs, &(&1.name == :name))
      assert Enum.any?(attrs, &(&1.name == :description))
      assert Enum.any?(attrs, &(&1.name == :tagline))
    end

    test "returns translatable attributes with correct types" do
      attrs = Info.translatable_attributes(ProductResource)

      name_attr = Enum.find(attrs, &(&1.name == :name))
      desc_attr = Enum.find(attrs, &(&1.name == :description))

      assert name_attr.type == :string
      assert desc_attr.type == :text
    end

    test "returns translatable attributes with correct locales" do
      attrs = Info.translatable_attributes(ProductResource)

      name_attr = Enum.find(attrs, &(&1.name == :name))
      desc_attr = Enum.find(attrs, &(&1.name == :description))

      assert name_attr.locales == [:en, :es, :fr]
      assert desc_attr.locales == [:en, :es, :fr, :de]
    end

    test "returns translatable attributes with correct required locales" do
      attrs = Info.translatable_attributes(ProductResource)

      name_attr = Enum.find(attrs, &(&1.name == :name))

      assert name_attr.required == [:en]
    end

    test "returns translatable attributes with correct fallback" do
      attrs = Info.translatable_attributes(ProductResource)

      desc_attr = Enum.find(attrs, &(&1.name == :description))

      assert desc_attr.fallback == :en
    end

    test "returns translatable attributes with correct markdown flag" do
      attrs = Info.translatable_attributes(ProductResource)

      tagline_attr = Enum.find(attrs, &(&1.name == :tagline))

      assert tagline_attr.markdown == true
    end

    test "returns empty list for non-translatable resource" do
      attrs = Info.translatable_attributes(NonTranslatableResource)

      assert attrs == []
    end

    test "returns minimal configuration correctly" do
      attrs = Info.translatable_attributes(CategoryResource)

      assert length(attrs) == 1

      title_attr = List.first(attrs)
      assert title_attr.name == :title
      assert title_attr.type == :string
      assert title_attr.locales == [:en, :de]
    end
  end

  describe "translatable_attribute/2" do
    test "returns specific attribute by name" do
      attr = Info.translatable_attribute(ProductResource, :name)

      assert attr != nil
      assert attr.name == :name
      assert attr.type == :string
      assert attr.locales == [:en, :es, :fr]
    end

    test "returns nil for non-existent attribute" do
      attr = Info.translatable_attribute(ProductResource, :nonexistent)

      assert attr == nil
    end

    test "returns nil for non-translatable attribute" do
      attr = Info.translatable_attribute(ProductResource, :sku)

      assert attr == nil
    end

    test "returns nil for non-translatable resource" do
      attr = Info.translatable_attribute(NonTranslatableResource, :name)

      assert attr == nil
    end

    test "returns correct attribute from minimal configuration" do
      attr = Info.translatable_attribute(CategoryResource, :title)

      assert attr != nil
      assert attr.name == :title
      assert attr.locales == [:en, :de]
    end
  end

  describe "supported_locales/1" do
    test "returns all unique locales across attributes" do
      locales = Info.supported_locales(ProductResource)

      assert :en in locales
      assert :es in locales
      assert :fr in locales
      assert :de in locales
    end

    test "returns deduplicated locales" do
      locales = Info.supported_locales(ProductResource)

      # Should have exactly 4 unique locales
      assert length(locales) == 4
      assert length(Enum.uniq(locales)) == 4
    end

    test "returns sorted locales" do
      locales = Info.supported_locales(ProductResource)

      assert locales == Enum.sort(locales)
    end

    test "returns empty list for non-translatable resource" do
      locales = Info.supported_locales(NonTranslatableResource)

      assert locales == []
    end

    test "returns locales for minimal configuration" do
      locales = Info.supported_locales(CategoryResource)

      assert locales == [:de, :en]
    end

    test "handles single attribute with multiple locales" do
      locales = Info.supported_locales(CategoryResource)

      assert :en in locales
      assert :de in locales
      assert length(locales) == 2
    end
  end

  describe "translatable?/1" do
    test "returns true for resource with translatable attributes" do
      assert Info.translatable?(ProductResource) == true
    end

    test "returns true for resource with single translatable attribute" do
      assert Info.translatable?(CategoryResource) == true
    end

    test "returns false for resource without translatable attributes" do
      assert Info.translatable?(NonTranslatableResource) == false
    end
  end

  describe "backend/1" do
    test "returns configured backend" do
      assert Info.backend(ProductResource) == :database
    end

    test "returns gettext backend when configured" do
      assert Info.backend(CategoryResource) == :gettext
    end

    test "returns default backend for non-translatable resource" do
      backend = Info.backend(NonTranslatableResource)

      # Should return default :database
      assert backend == :database
    end

    test "returns database as default when not specified" do
      defmodule DefaultBackendResource do
        @moduledoc false
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Ets,
          extensions: [AshPhoenixTranslations]

        translations do
          translatable_attribute :name, :string, locales: [:en]
        end

        attributes do
          uuid_primary_key :id
        end

        actions do
          defaults [:read]
        end
      end

      assert Info.backend(DefaultBackendResource) == :database
    end
  end

  describe "cache_ttl/1" do
    test "returns configured cache TTL" do
      assert Info.cache_ttl(ProductResource) == 7200
    end

    test "returns default TTL when not configured" do
      assert Info.cache_ttl(CategoryResource) == 3600
    end

    test "returns default TTL for non-translatable resource" do
      ttl = Info.cache_ttl(NonTranslatableResource)

      assert ttl == 3600
    end
  end

  describe "audit_changes?/1" do
    test "returns true when audit changes enabled" do
      assert Info.audit_changes?(ProductResource) == true
    end

    test "returns false when not configured (default)" do
      assert Info.audit_changes?(CategoryResource) == false
    end

    test "returns false for non-translatable resource" do
      assert Info.audit_changes?(NonTranslatableResource) == false
    end
  end

  describe "auto_validate?/1" do
    test "returns true when not configured (default)" do
      assert Info.auto_validate?(CategoryResource) == true
    end

    test "returns false when explicitly disabled" do
      assert Info.auto_validate?(ProductResource) == false
    end

    test "returns true for non-translatable resource (default)" do
      assert Info.auto_validate?(NonTranslatableResource) == true
    end
  end

  describe "storage_field/1" do
    test "generates correct storage field name" do
      assert Info.storage_field(:name) == :name_translations
    end

    test "generates correct storage field for multi-word attribute" do
      assert Info.storage_field(:product_name) == :product_name_translations
    end

    test "generates correct storage field for description" do
      assert Info.storage_field(:description) == :description_translations
    end

    test "handles single character attribute names" do
      assert Info.storage_field(:a) == :a_translations
    end
  end

  describe "all_translations_field/1" do
    test "generates correct all translations field name" do
      assert Info.all_translations_field(:name) == :name_all_translations
    end

    test "generates correct field for multi-word attribute" do
      assert Info.all_translations_field(:product_name) == :product_name_all_translations
    end

    test "generates correct field for description" do
      assert Info.all_translations_field(:description) == :description_all_translations
    end

    test "handles single character attribute names" do
      assert Info.all_translations_field(:a) == :a_all_translations
    end
  end

  describe "translation_policies/1" do
    test "returns configured policies" do
      policies = Info.translation_policies(PolicyResource)

      assert policies != nil
      assert Keyword.keyword?(policies)
    end

    test "returns nil when no policies configured" do
      policies = Info.translation_policies(ProductResource)

      assert policies == nil
    end

    test "returns nil for non-translatable resource" do
      policies = Info.translation_policies(NonTranslatableResource)

      assert policies == nil
    end
  end

  describe "view_policy/1" do
    test "returns configured view policy" do
      policy = Info.view_policy(PolicyResource)

      assert policy == :admin
    end

    test "returns default :public when no policies configured" do
      policy = Info.view_policy(ProductResource)

      assert policy == :public
    end

    test "returns default :public for non-translatable resource" do
      policy = Info.view_policy(NonTranslatableResource)

      assert policy == :public
    end
  end

  describe "edit_policy/1" do
    test "returns configured edit policy" do
      policy = Info.edit_policy(PolicyResource)

      assert policy == {:role, [:translator]}
    end

    test "returns default :admin when no policies configured" do
      policy = Info.edit_policy(ProductResource)

      assert policy == :admin
    end

    test "returns default :admin for non-translatable resource" do
      policy = Info.edit_policy(NonTranslatableResource)

      assert policy == :admin
    end
  end

  describe "approval_policy/1" do
    test "returns configured approval policy" do
      policy = Info.approval_policy(PolicyResource)

      assert policy != nil
      assert Keyword.keyword?(policy)
      assert policy[:approvers] == [:admin]
      assert policy[:required_for] == [:production]
    end

    test "returns nil when no approval policy configured" do
      policy = Info.approval_policy(ProductResource)

      assert policy == nil
    end

    test "returns nil for non-translatable resource" do
      policy = Info.approval_policy(NonTranslatableResource)

      assert policy == nil
    end
  end

  describe "edge cases and error conditions" do
    test "handles resource with no attributes gracefully" do
      defmodule EmptyTranslationsResource do
        @moduledoc false
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Ets,
          extensions: [AshPhoenixTranslations]

        translations do
          backend :database
        end

        attributes do
          uuid_primary_key :id
        end

        actions do
          defaults [:read]
        end
      end

      assert Info.translatable?(EmptyTranslationsResource) == false
      assert Info.translatable_attributes(EmptyTranslationsResource) == []
      assert Info.supported_locales(EmptyTranslationsResource) == []
    end

    test "handles multiple resources independently" do
      # Verify that different resources maintain separate configurations
      assert Info.backend(ProductResource) == :database
      assert Info.backend(CategoryResource) == :gettext

      assert Info.cache_ttl(ProductResource) == 7200
      assert Info.cache_ttl(CategoryResource) == 3600

      assert Info.audit_changes?(ProductResource) == true
      assert Info.audit_changes?(CategoryResource) == false
    end

    test "field name generators work consistently" do
      attrs = [:name, :description, :title, :content]

      for attr <- attrs do
        storage = Info.storage_field(attr)
        all_trans = Info.all_translations_field(attr)

        # Storage field should end with _translations
        assert String.ends_with?(Atom.to_string(storage), "_translations")

        # All translations field should end with _all_translations
        assert String.ends_with?(Atom.to_string(all_trans), "_all_translations")

        # Both should start with the original attribute name
        attr_str = Atom.to_string(attr)
        assert String.starts_with?(Atom.to_string(storage), attr_str)
        assert String.starts_with?(Atom.to_string(all_trans), attr_str)
      end
    end

    test "supported locales handles overlapping locales correctly" do
      # ProductResource has overlapping locales across attributes
      # :name -> [:en, :es, :fr]
      # :description -> [:en, :es, :fr, :de]
      # :tagline -> [:en, :es]
      # Should result in [:de, :en, :es, :fr] (sorted and unique)

      locales = Info.supported_locales(ProductResource)

      assert locales == [:de, :en, :es, :fr]
      assert length(locales) == 4
    end
  end

  describe "integration with Spark.Dsl" do
    test "works with persisted attributes" do
      # Info module tries persisted data first, then falls back to entities
      attrs = Info.translatable_attributes(ProductResource)

      # Should return valid TranslatableAttribute structs
      assert Enum.all?(attrs, &is_struct(&1, AshPhoenixTranslations.TranslatableAttribute))
    end

    test "all introspection functions work together coherently" do
      # Test that all introspection functions return coherent data
      attrs = Info.translatable_attributes(ProductResource)
      locales = Info.supported_locales(ProductResource)
      backend = Info.backend(ProductResource)
      ttl = Info.cache_ttl(ProductResource)

      # Attributes should contribute to supported locales
      attr_locales = attrs |> Enum.flat_map(& &1.locales) |> Enum.uniq() |> Enum.sort()
      assert attr_locales == locales

      # Backend should be consistent
      assert backend in [:database, :gettext]

      # TTL should be positive integer
      assert is_integer(ttl) and ttl > 0
    end
  end
end
