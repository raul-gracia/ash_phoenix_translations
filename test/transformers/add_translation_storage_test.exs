defmodule AshPhoenixTranslations.Transformers.AddTranslationStorageTest do
  @moduledoc """
  Tests for the AddTranslationStorage transformer.

  This transformer is the first in the transformation pipeline and adds the appropriate
  storage attributes to resources based on the configured backend (database or gettext).

  ## Transformer Purpose

  The `AddTranslationStorage` transformer modifies Ash resources to add storage attributes
  for translation data. The behavior differs based on backend:

  ### Database Backend
  Adds Map-type storage attributes with locale constraints:
  - Attribute name: `{field}_translations` (e.g., `:name_translations`)
  - Type: `Ash.Type.Map`
  - Public: `true` (required for update_translation action)
  - Default: `%{}`
  - Constraints: Field definitions for each supported locale

  ### Gettext Backend
  No storage attributes needed - translations stored in .po files

  ## Test Coverage

  ### Database Backend
  - Map storage attributes are added for each translatable field
  - Attributes follow naming convention: `field_translations`
  - Attributes are public (accessible via API)
  - Default value is empty map
  - Locale constraints are properly configured
  - Type is Ash.Type.Map

  ### Gettext Backend
  - No storage attributes are added
  - Resource remains clean (no extra fields)
  - Gettext backend relies on external .po files

  ## Storage Attribute Structure

  For a translatable field `:name` with locales `[:en, :es, :fr]`:

      attribute :name_translations, Ash.Type.Map do
        public? true
        default %{}
        constraints [
          fields: [
            en: [type: :string],
            es: [type: :string],
            fr: [type: :string]
          ]
        ]
      end

  ## Why Storage Attributes Must Be Public

  Storage attributes must be `public? true` because:

  1. The `update_translation` action needs to accept them as input
  2. API clients need to provide translation data during create/update
  3. GraphQL and JSON:API integrations require field accessibility

  Previous versions used `public? false` for security, but this prevented
  the `update_translation` action from functioning correctly.

  ## Transformer Execution Order

  This transformer runs first in the pipeline:

      1. AddTranslationStorage (this one) ← Creates storage fields
      2. AddTranslationRelationships       ← Adds audit relationships
      3. AddTranslationActions             ← Adds update_translation action
      4. AddTranslationCalculations        ← Adds locale-aware calculations
      5. AddTranslationChanges             ← Adds validation changes
      6. SetupTranslationPolicies          ← Configures access policies

  ## Running Tests

      # Run all storage transformer tests
      mix test test/transformers/add_translation_storage_test.exs

      # Run specific backend test
      mix test test/transformers/add_translation_storage_test.exs --only describe:"Database Backend"

      # Run with detailed trace
      mix test test/transformers/add_translation_storage_test.exs --trace

  ## Test Resources

  Each test defines minimal resources with translation configuration:

      defmodule DatabaseProduct do
        use Ash.Resource,
          extensions: [AshPhoenixTranslations]

        translations do
          translatable_attribute :name, :string do
            locales [:en, :es, :fr]
          end

          backend :database
        end
      end

  ## Key Assertions

  The tests verify critical properties:

      # Storage attribute exists
      assert :name_translations in Ash.Resource.Info.attribute_names(DatabaseProduct)

      # Correct type
      attr = Ash.Resource.Info.attribute(DatabaseProduct, :name_translations)
      assert attr.type == Ash.Type.Map

      # Public accessibility
      assert attr.public? == true

      # Default value
      assert attr.default == %{}

      # Locale constraints
      assert attr.constraints[:fields][:en]
      assert attr.constraints[:fields][:es]
      assert attr.constraints[:fields][:fr]

  ## Related Tests

  - `add_translation_actions_test.exs` - Verifies update_translation action
  - `add_translation_calculations_test.exs` - Verifies calculation field access
  - `ash_phoenix_translations_test.exs` - Integration tests with storage
  """
  use ExUnit.Case

  describe "Database Backend" do
    defmodule DatabaseProduct do
      use Ash.Resource,
        domain: AshPhoenixTranslations.Transformers.AddTranslationStorageTest.Domain,
        data_layer: Ash.DataLayer.Ets,
        extensions: [AshPhoenixTranslations]

      ets do
        table :test_database_products
      end

      translations do
        translatable_attribute :name, :string do
          locales [:en, :es, :fr]
          required [:en]
          validation(max_length: 100)
        end

        translatable_attribute :description, :text do
          locales [:en, :es]
          fallback(:en)
        end

        backend :database
      end

      actions do
        defaults [:create, :read, :update, :destroy]
      end

      attributes do
        uuid_primary_key :id
        timestamps()
      end
    end

    test "adds map storage attributes for database backend" do
      resource_info = Ash.Resource.Info
      attributes = resource_info.attribute_names(DatabaseProduct)

      # Should have translation storage fields
      assert :name_translations in attributes
      assert :description_translations in attributes

      # Check the storage attribute details
      name_attr = resource_info.attribute(DatabaseProduct, :name_translations)
      assert name_attr.type == Ash.Type.Map
      # Storage attributes must be public for update_translation action
      assert name_attr.public? == true
      assert name_attr.default == %{}

      # Check constraints are properly set
      assert name_attr.constraints[:fields][:en]
      assert name_attr.constraints[:fields][:es]
      assert name_attr.constraints[:fields][:fr]
    end

    test "storage attributes are public for update_translation action" do
      resource_info = Ash.Resource.Info

      public_attrs =
        DatabaseProduct
        |> resource_info.attributes()
        |> Enum.filter(& &1.public?)
        |> Enum.map(& &1.name)

      # Storage attributes must be public for update_translation action to work
      assert :name_translations in public_attrs
      assert :description_translations in public_attrs
    end
  end

  describe "Gettext Backend" do
    defmodule GettextProduct do
      use Ash.Resource,
        domain: AshPhoenixTranslations.Transformers.AddTranslationStorageTest.Domain,
        data_layer: Ash.DataLayer.Ets,
        extensions: [AshPhoenixTranslations]

      ets do
        table :test_gettext_products
      end

      translations do
        translatable_attribute :name, :string do
          locales [:en, :es, :fr]
        end

        backend :gettext
      end

      actions do
        defaults [:create, :read, :update, :destroy]
      end

      attributes do
        uuid_primary_key :id
        timestamps()
      end
    end

    test "does not add storage attributes for gettext backend" do
      resource_info = Ash.Resource.Info
      attributes = resource_info.attribute_names(GettextProduct)

      # Should NOT have translation storage fields for gettext
      refute :name_translations in attributes
      refute :name_gettext_key in attributes
    end
  end

  # Test domain
  defmodule Domain do
    use Ash.Domain,
      validate_config_inclusion?: false

    resources do
      resource AshPhoenixTranslations.Transformers.AddTranslationStorageTest.DatabaseProduct
      resource AshPhoenixTranslations.Transformers.AddTranslationStorageTest.GettextProduct
    end
  end
end
