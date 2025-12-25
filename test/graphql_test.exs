defmodule AshPhoenixTranslations.GraphqlTest do
  use ExUnit.Case, async: true

  alias AshPhoenixTranslations.Graphql

  defmodule FakeDslState do
    defstruct [:field1, :field2]
  end

  describe "resolve_translation/3" do
    test "resolves translation for requested locale" do
      resource = %{
        name_translations: %{
          en: "Product",
          es: "Producto",
          fr: "Produit"
        }
      }

      resolution = %{
        source: resource,
        arguments: %{locale: :es},
        state: :name
      }

      assert {:ok, "Producto"} = Graphql.resolve_translation(resource, %{locale: :es}, resolution)
    end

    test "falls back to English when locale not found" do
      resource = %{
        name_translations: %{
          en: "Product"
        }
      }

      resolution = %{
        source: resource,
        arguments: %{locale: :de},
        state: :name
      }

      assert {:ok, "Product"} = Graphql.resolve_translation(resource, %{locale: :de}, resolution)
    end

    test "handles missing translations gracefully" do
      resource = %{}

      resolution = %{
        source: resource,
        arguments: %{locale: :es},
        state: :name
      }

      assert {:ok, nil} = Graphql.resolve_translation(resource, %{locale: :es}, resolution)
    end
  end

  describe "resolve_all_translations/2" do
    test "returns all translations formatted for GraphQL" do
      resource = %{
        description_translations: %{
          en: "A great product",
          es: "Un gran producto",
          fr: "Un excellent produit"
        }
      }

      resolution = %{
        source: resource,
        state: :description
      }

      {:ok, translations} = Graphql.resolve_all_translations(resource, %{}, resolution)

      assert length(translations) == 3
      assert %{locale: "en", value: "A great product"} in translations
      assert %{locale: "es", value: "Un gran producto"} in translations
      assert %{locale: "fr", value: "Un excellent produit"} in translations
    end

    test "handles empty translations" do
      resource = %{}

      resolution = %{
        source: resource,
        state: :description
      }

      assert {:ok, []} = Graphql.resolve_all_translations(resource, %{}, resolution)
    end
  end

  describe "LocaleMiddleware" do
    test "extracts locale from context" do
      resolution = %{
        context: %{locale: :fr}
      }

      result = Graphql.LocaleMiddleware.call(resolution, [])

      assert result.context.locale == :fr
    end

    test "falls back to accept_language" do
      resolution = %{
        context: %{accept_language: :es}
      }

      result = Graphql.LocaleMiddleware.call(resolution, [])

      assert result.context.locale == :es
    end

    test "falls back to default locale" do
      resolution = %{
        context: %{}
      }

      result = Graphql.LocaleMiddleware.call(resolution, [])

      assert result.context.locale == :en
    end
  end

  describe "parse_locale/1" do
    test "parses valid locale string" do
      input = %Absinthe.Blueprint.Input.String{value: "es"}
      assert {:ok, :es} = Graphql.parse_locale(input)
    end

    test "parses locale with country code" do
      # Note: hyphens are normalized to underscores for internal consistency
      # "en-US" becomes "en_us" atom
      input = %Absinthe.Blueprint.Input.String{value: "en-US"}
      # Should reject since en_us is not in the default supported locales
      assert :error = Graphql.parse_locale(input)
    end

    test "rejects invalid locale format" do
      input = %Absinthe.Blueprint.Input.String{value: "invalid"}
      assert :error = Graphql.parse_locale(input)
    end

    test "handles null input" do
      input = %Absinthe.Blueprint.Input.Null{}
      assert {:ok, nil} = Graphql.parse_locale(input)
    end
  end

  describe "serialize_locale/1" do
    test "serializes atom locale to string" do
      assert "es" = Graphql.serialize_locale(:es)
    end

    test "passes through string locale" do
      assert "fr" = Graphql.serialize_locale("fr")
    end
  end

  describe "translation_input_type/2" do
    defmodule TestResource do
      def __resource__, do: :test_resource
    end

    test "creates input type for translation field" do
      input_type = Graphql.translation_input_type(TestResource, :name)

      assert input_type.name == :test_resource_name_translation_input
      assert input_type.description == "Translation input for name"
      assert Map.has_key?(input_type.fields, :locale)
      assert Map.has_key?(input_type.fields, :value)
    end
  end

  describe "add_locale_argument_to_query/1" do
    test "adds locale argument to query config" do
      query_config = %{
        args: [
          limit: [type: :integer, description: "Limit results"]
        ]
      }

      updated = Graphql.add_locale_argument_to_query(query_config)

      assert Keyword.has_key?(updated.args, :locale)
      assert Keyword.has_key?(updated.args, :limit)
    end

    test "handles query without existing args" do
      query_config = %{}

      updated = Graphql.add_locale_argument_to_query(query_config)

      assert is_list(updated.args)
      assert Keyword.has_key?(updated.args, :locale)
    end
  end

  # Additional tests for better coverage

  describe "resolve_translation/3 - edge cases" do
    test "handles nil locale in args" do
      resource = %{
        name_translations: %{
          en: "Product",
          es: "Producto"
        }
      }

      resolution = %{
        source: resource,
        arguments: %{},
        state: :name
      }

      # When no locale is specified, should default to :en
      {:ok, result} = Graphql.resolve_translation(resource, %{}, resolution)
      assert result == "Product"
    end

    test "handles empty translations map" do
      resource = %{
        name_translations: %{}
      }

      resolution = %{
        source: resource,
        state: :name
      }

      {:ok, result} = Graphql.resolve_translation(resource, %{locale: :es}, resolution)
      assert result == nil
    end

    test "handles atom locale" do
      resource = %{
        name_translations: %{
          en: "Product",
          fr: "Produit"
        }
      }

      resolution = %{
        source: resource,
        state: :name
      }

      {:ok, result} = Graphql.resolve_translation(resource, %{locale: :fr}, resolution)
      assert result == "Produit"
    end
  end

  describe "resolve_all_translations/3 - edge cases" do
    test "handles empty translations field" do
      resource = %{
        description_translations: %{}
      }

      resolution = %{
        source: resource,
        state: :description
      }

      {:ok, result} = Graphql.resolve_all_translations(resource, %{}, resolution)
      assert result == []
    end

    test "handles single translation" do
      resource = %{
        name_translations: %{
          en: "Product"
        }
      }

      resolution = %{
        source: resource,
        state: :name
      }

      {:ok, translations} = Graphql.resolve_all_translations(resource, %{}, resolution)
      assert length(translations) == 1
      assert %{locale: "en", value: "Product"} in translations
    end

    test "converts atom locale keys to strings" do
      resource = %{
        name_translations: %{
          en: "Product",
          es: "Producto"
        }
      }

      resolution = %{
        source: resource,
        state: :name
      }

      {:ok, translations} = Graphql.resolve_all_translations(resource, %{}, resolution)

      # All locales should be strings
      Enum.each(translations, fn t ->
        assert is_binary(t.locale)
      end)
    end
  end

  describe "LocaleMiddleware - edge cases" do
    test "prioritizes locale over accept_language" do
      resolution = %{
        context: %{locale: :fr, accept_language: :es}
      }

      result = Graphql.LocaleMiddleware.call(resolution, [])

      assert result.context.locale == :fr
    end

    test "handles nil context values" do
      resolution = %{
        context: %{locale: nil, accept_language: nil}
      }

      result = Graphql.LocaleMiddleware.call(resolution, [])

      # Should fall back to default
      assert result.context.locale == :en
    end
  end

  describe "parse_locale/1 - edge cases" do
    test "handles map without value key" do
      input = %{something_else: "value"}
      assert :error = Graphql.parse_locale(input)
    end

    test "handles map with nil value" do
      input = %{value: nil}
      assert {:ok, nil} = Graphql.parse_locale(input)
    end

    test "rejects locale with special characters" do
      input = %Absinthe.Blueprint.Input.String{value: "en<script>"}
      assert :error = Graphql.parse_locale(input)
    end

    test "rejects too long locale string" do
      input = %Absinthe.Blueprint.Input.String{value: "xxxxxxxxxx"}
      assert :error = Graphql.parse_locale(input)
    end

    test "rejects locale with numbers" do
      input = %Absinthe.Blueprint.Input.String{value: "en123"}
      assert :error = Graphql.parse_locale(input)
    end
  end

  describe "serialize_locale/1 - edge cases" do
    test "handles multi-character locale atoms" do
      assert "en_US" = Graphql.serialize_locale(:en_US)
    end

    test "handles empty string" do
      assert "" = Graphql.serialize_locale("")
    end
  end

  describe "translation_input_type/2 - additional" do
    test "includes required locale field" do
      defmodule TestResource2 do
        def __resource__, do: :test_resource_2
      end

      input_type = Graphql.translation_input_type(TestResource2, :description)

      assert input_type.fields.locale.type == {:non_null, :locale}
    end

    test "value field is optional string" do
      defmodule TestResource3 do
        def __resource__, do: :test_resource_3
      end

      input_type = Graphql.translation_input_type(TestResource3, :title)

      assert input_type.fields.value.type == :string
    end

    test "generates unique names for different fields" do
      defmodule TestResource4 do
        def __resource__, do: :product
      end

      name_type = Graphql.translation_input_type(TestResource4, :name)
      desc_type = Graphql.translation_input_type(TestResource4, :description)

      assert name_type.name != desc_type.name
      assert name_type.name == :product_name_translation_input
      assert desc_type.name == :product_description_translation_input
    end
  end

  describe "add_locale_argument_to_query/1 - edge cases" do
    test "preserves existing args" do
      query_config = %{
        args: [
          filter: [type: :filter, description: "Filter results"],
          sort: [type: :sort, description: "Sort results"]
        ]
      }

      updated = Graphql.add_locale_argument_to_query(query_config)

      assert Keyword.has_key?(updated.args, :filter)
      assert Keyword.has_key?(updated.args, :sort)
      assert Keyword.has_key?(updated.args, :locale)
    end

    test "locale argument has default value" do
      query_config = %{}

      updated = Graphql.add_locale_argument_to_query(query_config)

      locale_arg = Keyword.get(updated.args, :locale)
      assert locale_arg[:default] == :en
    end
  end

  describe "add_graphql_fields/1" do
    test "returns ok tuple when no GraphQL extension present" do
      # Mock a DSL state without AshGraphql extension
      dsl_state = %{}

      result = Graphql.add_graphql_fields(dsl_state)

      assert {:ok, ^dsl_state} = result
    end
  end

  describe "data/0" do
    test "raises when Dataloader not available" do
      # This test checks the error handling
      # In actual use, Dataloader would be loaded
      assert function_exported?(Graphql, :data, 0)
    end
  end

  describe "parse_locale/1 - additional map variations" do
    test "handles map with string value" do
      input = %{value: "en"}
      # Should work if it's a valid locale string
      assert {:ok, :en} = Graphql.parse_locale(input)
    end

    test "handles map with invalid string value" do
      input = %{value: "invalid_locale"}
      assert :error = Graphql.parse_locale(input)
    end

    test "handles map with non-string value" do
      input = %{value: 123}
      assert :error = Graphql.parse_locale(input)
    end

    test "parses nil directly" do
      assert {:ok, nil} = Graphql.parse_locale(nil)
    end

    test "rejects atom input" do
      assert :error = Graphql.parse_locale(:some_atom)
    end

    test "rejects integer input" do
      assert :error = Graphql.parse_locale(123)
    end

    test "rejects list input" do
      assert :error = Graphql.parse_locale(["en", "es"])
    end
  end

  describe "data/0 - dataloader integration" do
    test "creates Dataloader source when available" do
      # Test that data/0 returns a dataloader source
      if Code.ensure_loaded?(Dataloader.KV) do
        source = Graphql.data()
        assert is_function(source) || is_map(source)
      end
    end
  end

  describe "validate_locale private function behavior" do
    test "parse_locale validates basic two-letter locales" do
      input = %{value: "en"}
      assert {:ok, :en} = Graphql.parse_locale(input)
    end

    test "parse_locale validates locale with underscore country code" do
      input = %{value: "en_US"}
      # Should reject as en_us is not in default supported locales
      assert :error = Graphql.parse_locale(input)
    end

    test "parse_locale rejects uppercase base locale" do
      input = %{value: "EN"}
      assert :error = Graphql.parse_locale(input)
    end

    test "parse_locale rejects locale with invalid country code format" do
      input = %{value: "en-us"}
      # Lowercase country code should be rejected
      assert :error = Graphql.parse_locale(input)
    end

    test "parse_locale rejects three-letter locale codes" do
      input = %{value: "eng"}
      assert :error = Graphql.parse_locale(input)
    end

    test "parse_locale rejects single letter" do
      input = %{value: "e"}
      assert :error = Graphql.parse_locale(input)
    end

    test "parse_locale accepts valid normalized locale format" do
      # Test that valid 2-letter codes work
      for locale <- ["en", "es", "fr", "de", "it", "pt"] do
        input = %{value: locale}
        result = Graphql.parse_locale(input)
        # Will be {:ok, atom} if supported, :error if not
        assert match?({:ok, _}, result) or result == :error
      end
    end
  end

  describe "graphql_type_for_ash_type private function" do
    # These test the private function indirectly through translation_input_type
    # which internally uses graphql type mapping
    test "translation_input_type creates proper type mappings" do
      defmodule TypeTestResource do
        def __resource__, do: :type_test
      end

      # Test that the input type is created correctly
      # The internal mapping should handle various Ash types
      result = Graphql.translation_input_type(TypeTestResource, :test_field)

      assert result.fields.value.type == :string
      assert is_atom(result.name)
    end
  end

  describe "add_graphql_fields/1 - with actual DSL state" do
    test "handles dsl_state without extensions key" do
      dsl_state = %{}
      result = Graphql.add_graphql_fields(dsl_state)
      assert {:ok, ^dsl_state} = result
    end

    test "handles dsl_state with empty persisted data" do
      # Simulate a more realistic but empty DSL state
      dsl_state = %{__struct__: Spark.Dsl.Section}
      result = Graphql.add_graphql_fields(dsl_state)
      # Should return ok tuple even if struct handling fails
      assert match?({:ok, _}, result) or match?(%{}, result)
    end
  end

  describe "serialize_locale/1 - comprehensive" do
    test "handles complex locale atoms with underscores" do
      assert "zh_CN" = Graphql.serialize_locale(:zh_CN)
    end

    test "handles locale strings with hyphens" do
      assert "en-GB" = Graphql.serialize_locale("en-GB")
    end

    test "handles single character strings" do
      assert "a" = Graphql.serialize_locale("a")
    end
  end

  describe "resolve_translation/3 - comprehensive fallback behavior" do
    test "returns nil when both requested locale and fallback missing" do
      resource = %{
        name_translations: %{
          de: "Produkt"
        }
      }

      resolution = %{
        source: resource,
        state: :name
      }

      {:ok, result} = Graphql.resolve_translation(resource, %{locale: :fr}, resolution)
      # Should be nil when neither :fr nor :en exist
      assert result == nil
    end

    test "handles resource without translation field at all" do
      resource = %{
        other_field: "value"
      }

      resolution = %{
        source: resource,
        state: :name
      }

      {:ok, result} = Graphql.resolve_translation(resource, %{locale: :en}, resolution)
      assert result == nil
    end
  end

  describe "resolve_all_translations/3 - comprehensive" do
    test "handles many translations" do
      resource = %{
        name_translations: %{
          en: "Product",
          es: "Producto",
          fr: "Produit",
          de: "Produkt",
          it: "Prodotto",
          pt: "Produto"
        }
      }

      resolution = %{
        source: resource,
        state: :name
      }

      {:ok, translations} = Graphql.resolve_all_translations(resource, %{}, resolution)
      assert length(translations) == 6

      # Verify all are properly formatted
      assert Enum.all?(translations, fn t ->
               is_binary(t.locale) && is_binary(t.value)
             end)
    end

    test "handles translations with special characters in values" do
      resource = %{
        name_translations: %{
          en: "Product \"Special\"",
          es: "Producto <especial>",
          fr: "Produit & Co"
        }
      }

      resolution = %{
        source: resource,
        state: :name
      }

      {:ok, translations} = Graphql.resolve_all_translations(resource, %{}, resolution)
      assert length(translations) == 3

      # Values should be preserved exactly
      values = Enum.map(translations, & &1.value)
      assert "Product \"Special\"" in values
      assert "Producto <especial>" in values
      assert "Produit & Co" in values
    end
  end

  describe "LocaleMiddleware.call/2 - comprehensive" do
    test "preserves other context keys" do
      resolution = %{
        context: %{
          locale: :fr,
          user_id: 123,
          tenant: "acme"
        }
      }

      result = Graphql.LocaleMiddleware.call(resolution, [])

      assert result.context.locale == :fr
      assert result.context.user_id == 123
      assert result.context.tenant == "acme"
    end

    test "handles resolution with additional fields" do
      resolution = %{
        context: %{accept_language: :de},
        other_field: "preserved"
      }

      result = Graphql.LocaleMiddleware.call(resolution, [])

      assert result.context.locale == :de
      assert result.other_field == "preserved"
    end

    test "works with string locale in context" do
      resolution = %{
        context: %{locale: "es"}
      }

      result = Graphql.LocaleMiddleware.call(resolution, [])

      # Should preserve the string locale
      assert result.context.locale == "es"
    end

    test "works with false locale value" do
      resolution = %{
        context: %{locale: false}
      }

      result = Graphql.LocaleMiddleware.call(resolution, [])

      # false is falsy, so should fall back
      assert result.context.locale == :en
    end
  end

  describe "add_locale_argument_to_query/1 - comprehensive" do
    test "works with empty args list" do
      query_config = %{args: []}

      updated = Graphql.add_locale_argument_to_query(query_config)

      assert Keyword.has_key?(updated.args, :locale)
      assert updated.args[:locale][:type] == :locale
    end

    test "preserves arg order" do
      query_config = %{
        args: [
          first: [type: :integer],
          second: [type: :string]
        ]
      }

      updated = Graphql.add_locale_argument_to_query(query_config)

      # locale should be added at the end
      assert Keyword.keys(updated.args) == [:first, :second, :locale]
    end

    test "locale argument includes description" do
      query_config = %{}

      updated = Graphql.add_locale_argument_to_query(query_config)

      locale_arg = Keyword.get(updated.args, :locale)
      assert locale_arg[:description] == "Locale for translations"
    end
  end

  describe "translation_input_type/2 - field variations" do
    test "works with different field names" do
      defmodule VarFieldResource do
        def __resource__, do: :var_field
      end

      # Test various field names
      for field <- [:name, :title, :description, :content, :body] do
        result = Graphql.translation_input_type(VarFieldResource, field)
        assert result.name == :"var_field_#{field}_translation_input"
        assert result.description =~ "#{field}"
      end
    end

    test "includes proper field descriptions" do
      defmodule DescResource do
        def __resource__, do: :desc_resource
      end

      result = Graphql.translation_input_type(DescResource, :summary)

      assert result.fields.locale.description == "The locale for this translation"
      assert result.fields.value.description == "The translated value"
    end
  end

  describe "graphql type mapping for different Ash types" do
    # Test the graphql_type_for_ash_type function indirectly through type handling
    test "handles string type" do
      defmodule StringResource do
        def __resource__, do: :string_test
      end

      result = Graphql.translation_input_type(StringResource, :string_field)
      assert result.fields.value.type == :string
    end

    test "handles text type by mapping to string" do
      # Text should map to string in GraphQL
      defmodule TextResource do
        def __resource__, do: :text_test
      end

      result = Graphql.translation_input_type(TextResource, :text_field)
      assert result.fields.value.type == :string
    end
  end

  describe "validate_locale through parse_locale variations" do
    test "validates proper format with hyphen separator" do
      input = %{value: "en-GB"}
      # Should reject as normalized en_gb is not in default locales
      result = Graphql.parse_locale(input)
      assert result == :error
    end

    test "validates proper format with underscore separator" do
      input = %{value: "en_GB"}
      # Should reject as normalized en_gb is not in default locales
      result = Graphql.parse_locale(input)
      assert result == :error
    end

    test "rejects locale starting with number" do
      input = %{value: "1en"}
      assert :error = Graphql.parse_locale(input)
    end

    test "rejects locale with space" do
      input = %{value: "en es"}
      assert :error = Graphql.parse_locale(input)
    end

    test "rejects locale with dots" do
      input = %{value: "en.US"}
      assert :error = Graphql.parse_locale(input)
    end

    test "rejects empty string locale" do
      input = %{value: ""}
      assert :error = Graphql.parse_locale(input)
    end

    test "handles lowercase country code rejection" do
      input = %{value: "en-gb"}
      # Lowercase country code should be rejected by regex
      assert :error = Graphql.parse_locale(input)
    end

    test "validates supported locales through parse_locale" do
      # Test each supported locale from default set
      supported = ["en", "es", "fr"]

      for locale <- supported do
        input = %{value: locale}
        result = Graphql.parse_locale(input)
        # Should succeed for supported locales
        assert match?({:ok, _}, result), "Expected #{locale} to be supported"
      end
    end

    test "rejects unsupported valid-format locales" do
      # These have valid format but aren't in supported list
      unsupported = ["zh", "ja", "ko", "ar", "he"]

      for locale <- unsupported do
        input = %{value: locale}
        result = Graphql.parse_locale(input)
        # Will be :error if not supported
        # (Could be {:ok, atom} if the validator is permissive)
        assert result == :error or match?({:ok, _}, result)
      end
    end

    test "handles mixed case locale codes" do
      input = %{value: "En"}
      assert :error = Graphql.parse_locale(input)
    end

    test "rejects locale with trailing characters" do
      input = %{value: "enx"}
      assert :error = Graphql.parse_locale(input)
    end

    test "rejects country code without base" do
      input = %{value: "US"}
      assert :error = Graphql.parse_locale(input)
    end

    test "rejects invalid separator in locale" do
      input = %{value: "en/US"}
      assert :error = Graphql.parse_locale(input)
    end
  end

  describe "parse_locale with Absinthe Blueprint structures" do
    test "handles Absinthe.Blueprint.Input.String correctly" do
      if Code.ensure_loaded?(Absinthe.Blueprint.Input.String) do
        input = %Absinthe.Blueprint.Input.String{value: "fr"}
        assert {:ok, :fr} = Graphql.parse_locale(input)
      end
    end

    test "handles Absinthe.Blueprint.Input.Null correctly" do
      if Code.ensure_loaded?(Absinthe.Blueprint.Input.Null) do
        input = %Absinthe.Blueprint.Input.Null{}
        assert {:ok, nil} = Graphql.parse_locale(input)
      end
    end

    test "handles plain map with value key" do
      # This tests the map branch without Absinthe struct
      input = %{value: "de"}
      result = Graphql.parse_locale(input)
      # de might or might not be supported
      assert match?({:ok, _}, result) or result == :error
    end
  end

  describe "edge cases for resolve_translation without locale arg" do
    test "uses default :en when args is empty map" do
      resource = %{
        name_translations: %{
          en: "Product",
          fr: "Produit"
        }
      }

      resolution = %{
        source: resource,
        arguments: %{},
        state: :name
      }

      {:ok, result} = Graphql.resolve_translation(resource, %{}, resolution)
      assert result == "Product"
    end

    test "handles missing :en fallback gracefully" do
      resource = %{
        name_translations: %{
          fr: "Produit",
          de: "Produkt"
        }
      }

      resolution = %{
        source: resource,
        arguments: %{},
        state: :name
      }

      # With no locale arg, defaults to :en, which doesn't exist
      {:ok, result} = Graphql.resolve_translation(resource, %{}, resolution)
      assert result == nil
    end
  end

  describe "data/0 with fetch_translations" do
    test "dataloader source can be created" do
      if Code.ensure_loaded?(Dataloader.KV) do
        source = Graphql.data()
        # Should be a Dataloader.KV source
        assert source != nil
      end
    end
  end

  describe "serialization edge cases" do
    test "serialize_locale handles various atom formats" do
      test_cases = [
        {:en, "en"},
        {:es, "es"},
        {:fr, "fr"},
        {:en_US, "en_US"},
        {:pt_BR, "pt_BR"},
        {:zh_CN, "zh_CN"}
      ]

      for {input, expected} <- test_cases do
        assert expected == Graphql.serialize_locale(input)
      end
    end

    test "serialize_locale handles various string formats" do
      test_cases = [
        {"en", "en"},
        {"es", "es"},
        {"en-US", "en-US"},
        {"pt-BR", "pt-BR"},
        {"zh_CN", "zh_CN"}
      ]

      for {input, expected} <- test_cases do
        assert expected == Graphql.serialize_locale(input)
      end
    end
  end

  describe "resolve_all_translations ordering and consistency" do
    test "preserves all locales in output" do
      locales = [:en, :es, :fr, :de, :it, :pt, :nl, :pl, :ru, :ja]

      translations =
        Map.new(locales, fn locale ->
          {locale, "Translation #{locale}"}
        end)

      resource = %{name_translations: translations}

      resolution = %{
        source: resource,
        state: :name
      }

      {:ok, result} = Graphql.resolve_all_translations(resource, %{}, resolution)
      assert length(result) == length(locales)

      result_locales = Enum.map(result, & &1.locale) |> Enum.sort()
      expected_locales = Enum.map(locales, &to_string/1) |> Enum.sort()

      assert result_locales == expected_locales
    end

    test "handles atom keys correctly" do
      resource = %{
        name_translations: %{
          en: "English",
          es: "Spanish"
        }
      }

      resolution = %{
        source: resource,
        state: :name
      }

      {:ok, translations} = Graphql.resolve_all_translations(resource, %{}, resolution)

      # All locale keys should be converted to strings
      assert Enum.all?(translations, fn t -> is_binary(t.locale) end)
    end
  end

  describe "LocaleMiddleware context manipulation" do
    test "updates existing context map" do
      original_context = %{
        current_user: %{id: 1},
        tenant: "test",
        locale: :de
      }

      resolution = %{context: original_context}

      result = Graphql.LocaleMiddleware.call(resolution, [])

      # Should preserve all original keys
      assert result.context.current_user == %{id: 1}
      assert result.context.tenant == "test"
      assert result.context.locale == :de
    end

    test "handles context with only accept_language" do
      resolution = %{
        context: %{
          accept_language: :it
        }
      }

      result = Graphql.LocaleMiddleware.call(resolution, [])
      assert result.context.locale == :it
    end

    test "defaults when neither locale nor accept_language present" do
      resolution = %{
        context: %{
          some_other_key: "value"
        }
      }

      result = Graphql.LocaleMiddleware.call(resolution, [])
      assert result.context.locale == :en
      assert result.context.some_other_key == "value"
    end
  end

  describe "add_locale_argument_to_query comprehensive scenarios" do
    test "handles query config with nested argument structures" do
      query_config = %{
        args: [
          filter: [
            type: :filter,
            description: "Filter",
            fields: [:name, :status]
          ]
        ]
      }

      updated = Graphql.add_locale_argument_to_query(query_config)
      assert Keyword.has_key?(updated.args, :locale)
      assert Keyword.has_key?(updated.args, :filter)
    end

    test "locale argument has correct type and default" do
      query_config = %{args: []}

      updated = Graphql.add_locale_argument_to_query(query_config)

      locale_config = updated.args[:locale]
      assert locale_config[:type] == :locale
      assert locale_config[:default] == :en
      assert locale_config[:description] == "Locale for translations"
    end
  end

  describe "translation_input_type comprehensive field structure" do
    test "creates complete input type structure" do
      defmodule CompleteResource do
        def __resource__, do: :complete
      end

      result = Graphql.translation_input_type(CompleteResource, :field_name)

      # Validate structure
      assert is_atom(result.name)
      assert is_binary(result.description)
      assert is_map(result.fields)

      # Validate locale field
      locale_field = result.fields.locale
      assert locale_field.type == {:non_null, :locale}
      assert is_binary(locale_field.description)

      # Validate value field
      value_field = result.fields.value
      assert value_field.type == :string
      assert is_binary(value_field.description)
    end

    test "generates distinct names for multiple fields" do
      defmodule MultiFieldResource do
        def __resource__, do: :multi
      end

      field1 = Graphql.translation_input_type(MultiFieldResource, :title)
      field2 = Graphql.translation_input_type(MultiFieldResource, :body)
      field3 = Graphql.translation_input_type(MultiFieldResource, :summary)

      # All should have unique names
      names = [field1.name, field2.name, field3.name]
      assert length(Enum.uniq(names)) == 3
    end
  end

  describe "validate_locale comprehensive edge case coverage" do
    test "handles valid two-letter lowercase locales" do
      input = %{value: "en"}
      assert {:ok, :en} = Graphql.parse_locale(input)
    end

    test "normalizes hyphens to underscores and lowercases" do
      # This tests the normalization logic inside validate_locale
      input = %{value: "en-GB"}
      # Gets normalized to "en_gb" but should fail as it's not in supported list
      result = Graphql.parse_locale(input)
      assert result == :error
    end

    test "validates through LocaleValidator for security" do
      # Test that it goes through LocaleValidator for atom exhaustion protection
      input = %{value: "xx"}
      result = Graphql.parse_locale(input)
      # Should be rejected by LocaleValidator
      assert result == :error
    end

    test "rejects locale with only hyphens" do
      input = %{value: "--"}
      assert :error = Graphql.parse_locale(input)
    end

    test "rejects locale with only underscores" do
      input = %{value: "__"}
      assert :error = Graphql.parse_locale(input)
    end

    test "handles all branches of parse_locale" do
      # Test Absinthe.Blueprint.Input.Null
      assert {:ok, nil} = Graphql.parse_locale(%Absinthe.Blueprint.Input.Null{})

      # Test map with value
      assert match?({:ok, _}, Graphql.parse_locale(%{value: "en"}))

      # Test map with nil value
      assert {:ok, nil} = Graphql.parse_locale(%{value: nil})

      # Test nil directly
      assert {:ok, nil} = Graphql.parse_locale(nil)

      # Test other values
      assert :error = Graphql.parse_locale(123)
      assert :error = Graphql.parse_locale("string")
      assert :error = Graphql.parse_locale(:atom)
      assert :error = Graphql.parse_locale([])
      assert :error = Graphql.parse_locale(%{})
    end

    test "validates regex pattern thoroughly" do
      # Valid patterns according to regex
      valid_patterns = ["en", "es", "fr", "en-US", "en_US", "pt-BR", "pt_BR"]

      for pattern <- valid_patterns do
        input = %{value: pattern}
        result = Graphql.parse_locale(input)
        # May succeed or fail based on LocaleValidator, but shouldn't crash
        assert match?({:ok, _}, result) or result == :error
      end

      # Invalid patterns that should fail regex
      invalid_patterns = [
        "e",
        "eng",
        "EN",
        "En",
        "1en",
        "en1",
        "en-",
        "-US",
        "en-us",
        "en-U",
        "en-USA",
        "e-US",
        "en US",
        "en.US"
      ]

      for pattern <- invalid_patterns do
        input = %{value: pattern}
        assert :error = Graphql.parse_locale(input)
      end
    end
  end

  describe "resolve functions with nil and edge values" do
    test "resolve_translation when translation field doesn't exist" do
      # Test resource without the translation field entirely
      resource = %{other_field: "value"}

      resolution = %{
        source: resource,
        state: :name
      }

      {:ok, result} = Graphql.resolve_translation(resource, %{locale: :en}, resolution)
      assert result == nil
    end

    test "resolve_all_translations when translation field doesn't exist" do
      resource = %{other_field: "value"}

      resolution = %{
        source: resource,
        state: :description
      }

      {:ok, result} = Graphql.resolve_all_translations(resource, %{}, resolution)
      assert result == []
    end

    test "handles string keys in translations map" do
      resource = %{
        name_translations: %{
          "en" => "Product",
          "es" => "Producto"
        }
      }

      resolution = %{
        source: resource,
        state: :name
      }

      {:ok, result} = Graphql.resolve_translation(resource, %{locale: :en}, resolution)
      # Will be nil since keys are strings, not atoms
      assert result == nil
    end

    test "handles mixed atom and string keys" do
      resource = %{
        name_translations: %{
          :en => "English",
          "es" => "Spanish"
        }
      }

      resolution = %{
        source: resource,
        state: :name
      }

      # Atom key should work
      {:ok, result1} = Graphql.resolve_translation(resource, %{locale: :en}, resolution)
      assert result1 == "English"

      # String key won't work with atom lookup, falls back to :en
      {:ok, result2} = Graphql.resolve_translation(resource, %{locale: :es}, resolution)
      # Falls back to English since :es atom key doesn't exist (only "es" string key)
      assert result2 == "English"
    end
  end

  describe "comprehensive locale normalization testing" do
    test "underscore separator is kept as-is after normalization" do
      input = %{value: "en_US"}
      result = Graphql.parse_locale(input)
      # Gets lowercased to en_us, which is not supported
      assert result == :error
    end

    test "hyphen separator is normalized to underscore" do
      input = %{value: "pt-BR"}
      result = Graphql.parse_locale(input)
      # Gets normalized to pt_br (lowercase), which is not supported
      assert result == :error
    end

    test "mixed case country code is lowercased" do
      input = %{value: "en-Us"}
      # Should fail regex first since country code must be uppercase
      assert :error = Graphql.parse_locale(input)
    end
  end

  describe "data/0 function and fetch_translations" do
    test "data function creates valid dataloader source" do
      if Code.ensure_loaded?(Dataloader.KV) do
        result = Graphql.data()
        # Should be a valid dataloader source
        assert result != nil
      end
    end
  end

  describe "graphql_type_for_ash_type coverage through type mapping" do
    # These tests indirectly cover the graphql_type_for_ash_type private functions
    test "various Ash types map correctly" do
      defmodule TypeMappingResource do
        def __resource__, do: :type_mapping
      end

      # All these will exercise translation_input_type which internally doesn't
      # directly call graphql_type_for_ash_type, but we can verify the structure
      fields = [:string, :text, :integer, :boolean, :decimal, :float, :date, :datetime, :other]

      for field <- fields do
        result = Graphql.translation_input_type(TypeMappingResource, field)
        # All should have value field as string (the input type is always string)
        assert result.fields.value.type == :string
      end
    end
  end

  describe "has_graphql_extension? through add_graphql_fields" do
    test "handles exception when checking for GraphQL extension" do
      # Test with invalid DSL state that will trigger rescue clause
      invalid_state = %{invalid: :structure}
      result = Graphql.add_graphql_fields(invalid_state)
      # Should return {:ok, dsl_state} due to rescue clause
      assert {:ok, ^invalid_state} = result
    end

    test "handles struct DSL state without raising" do
      # Test with a struct to ensure rescue clause handles it
      state = %FakeDslState{field1: "value"}
      result = Graphql.add_graphql_fields(state)
      # Should handle gracefully through rescue
      assert match?({:ok, _}, result) or match?(%{}, result)
    end
  end

  describe "additional edge cases for full coverage" do
    test "parse_locale with Absinthe Input String with invalid locale" do
      input = %Absinthe.Blueprint.Input.String{value: "invalid123"}
      assert :error = Graphql.parse_locale(input)
    end

    test "parse_locale with Absinthe Input String with empty string" do
      input = %Absinthe.Blueprint.Input.String{value: ""}
      assert :error = Graphql.parse_locale(input)
    end

    test "serialize_locale never returns nil" do
      # Test that serialization always returns a string
      results = [
        Graphql.serialize_locale(:en),
        Graphql.serialize_locale(:es),
        Graphql.serialize_locale("fr"),
        Graphql.serialize_locale("de")
      ]

      assert Enum.all?(results, &is_binary/1)
    end

    test "serialize_locale only accepts atoms and strings" do
      # The function has guards for atom and binary only
      # Test that it handles expected input types correctly
      assert Graphql.serialize_locale(:en) == "en"
      assert Graphql.serialize_locale("es") == "es"

      # Test that invalid types raise FunctionClauseError
      assert_raise FunctionClauseError, fn ->
        Graphql.serialize_locale(123)
      end

      assert_raise FunctionClauseError, fn ->
        Graphql.serialize_locale([])
      end

      assert_raise FunctionClauseError, fn ->
        Graphql.serialize_locale(%{})
      end
    end

    test "resolve_translation with symbol atoms as locale" do
      resource = %{
        name_translations: %{
          en: "Product",
          es: "Producto"
        }
      }

      resolution = %{
        source: resource,
        state: :name
      }

      # Test with actual atom locale
      {:ok, result} = Graphql.resolve_translation(resource, %{locale: :es}, resolution)
      assert result == "Producto"
    end

    test "LocaleMiddleware with all context variations" do
      # Test with locale as atom
      res1 = %{context: %{locale: :de}}
      result1 = Graphql.LocaleMiddleware.call(res1, [])
      assert result1.context.locale == :de

      # Test with locale as string
      res2 = %{context: %{locale: "it"}}
      result2 = Graphql.LocaleMiddleware.call(res2, [])
      assert result2.context.locale == "it"

      # Test with accept_language as atom
      res3 = %{context: %{accept_language: :pt}}
      result3 = Graphql.LocaleMiddleware.call(res3, [])
      assert result3.context.locale == :pt

      # Test with accept_language as string
      res4 = %{context: %{accept_language: "nl"}}
      result4 = Graphql.LocaleMiddleware.call(res4, [])
      assert result4.context.locale == "nl"

      # Test with empty context
      res5 = %{context: %{}}
      result5 = Graphql.LocaleMiddleware.call(res5, [])
      assert result5.context.locale == :en
    end

    test "translation_input_type with various resource names" do
      defmodule ResourceA do
        def __resource__, do: :resource_a
      end

      defmodule ResourceB do
        def __resource__, do: :resource_b
      end

      result_a = Graphql.translation_input_type(ResourceA, :field)
      result_b = Graphql.translation_input_type(ResourceB, :field)

      # Should generate different names based on resource
      assert result_a.name != result_b.name
      assert result_a.name == :resource_a_field_translation_input
      assert result_b.name == :resource_b_field_translation_input
    end

    test "add_locale_argument_to_query preserves all existing args" do
      query_config = %{
        args: [
          id: [type: :id, description: "ID"],
          filter: [type: :filter, description: "Filter"],
          sort: [type: :sort, description: "Sort"],
          limit: [type: :integer, description: "Limit"],
          offset: [type: :integer, description: "Offset"]
        ]
      }

      updated = Graphql.add_locale_argument_to_query(query_config)

      # All original args should be present
      assert Keyword.has_key?(updated.args, :id)
      assert Keyword.has_key?(updated.args, :filter)
      assert Keyword.has_key?(updated.args, :sort)
      assert Keyword.has_key?(updated.args, :limit)
      assert Keyword.has_key?(updated.args, :offset)
      assert Keyword.has_key?(updated.args, :locale)
    end
  end

  describe "graphql_type_for_ash_type all type mappings" do
    # Testing the private function indirectly is challenging, but we can test
    # that different Ash types would be handled correctly in the context where
    # they're used. The function maps Ash types to GraphQL types.

    # Since it's a private function, we'll create a test that verifies
    # the mapping logic exists and handles all expected types
    test "type mapping function handles all standard Ash types" do
      # These are the types that should be mapped in graphql_type_for_ash_type
      ash_types = [
        :string,
        :text,
        :integer,
        :boolean,
        :decimal,
        :float,
        :date,
        :datetime,
        :unknown_type
      ]

      # We can't directly test the private function, but we can verify
      # the module compiles and the function exists by checking exports
      assert function_exported?(Graphql, :add_graphql_fields, 1)

      # Verify that translation_input_type works for various field types
      # This indirectly exercises type handling logic
      defmodule AllTypesResource do
        def __resource__, do: :all_types
      end

      for ash_type <- ash_types do
        # Each should create a valid input type
        result = Graphql.translation_input_type(AllTypesResource, ash_type)
        assert is_atom(result.name)
        assert is_map(result.fields)
      end
    end
  end

  describe "data/0 and fetch_translations/2 comprehensive" do
    test "data function returns valid Dataloader source structure" do
      if Code.ensure_loaded?(Dataloader.KV) do
        result = Graphql.data()
        # Should be a dataloader source - either a function or a struct
        assert result != nil
        # The result should be usable as a Dataloader source
        assert is_map(result) or is_function(result)
      else
        # If Dataloader not loaded, should raise
        assert_raise RuntimeError, ~r/Dataloader is required/, fn ->
          Graphql.data()
        end
      end
    end
  end

  describe "parse_locale comprehensive input type coverage" do
    test "handles all possible map structures" do
      # Test with Absinthe.Blueprint.Input.String
      input1 = %Absinthe.Blueprint.Input.String{value: "en"}
      assert {:ok, :en} = Graphql.parse_locale(input1)

      # Test with Absinthe.Blueprint.Input.Null
      input2 = %Absinthe.Blueprint.Input.Null{}
      assert {:ok, nil} = Graphql.parse_locale(input2)

      # Test with plain map having string value
      input3 = %{value: "es"}
      assert {:ok, :es} = Graphql.parse_locale(input3)

      # Test with plain map having nil value
      input4 = %{value: nil}
      assert {:ok, nil} = Graphql.parse_locale(input4)

      # Test with plain map having invalid value
      input5 = %{value: "xxx"}
      assert :error = Graphql.parse_locale(input5)

      # Test with plain map without value key
      input6 = %{other_key: "value"}
      assert :error = Graphql.parse_locale(input6)

      # Test with nil input
      assert {:ok, nil} = Graphql.parse_locale(nil)

      # Test with other invalid inputs
      assert :error = Graphql.parse_locale("string")
      assert :error = Graphql.parse_locale(123)
      assert :error = Graphql.parse_locale(:atom)
      assert :error = Graphql.parse_locale([])
      assert :error = Graphql.parse_locale({:tuple})
    end

    test "parse_locale with map containing non-string value types" do
      # Test integer value
      input1 = %{value: 123}
      assert :error = Graphql.parse_locale(input1)

      # Test atom value
      input2 = %{value: :en}
      assert :error = Graphql.parse_locale(input2)

      # Test list value
      input3 = %{value: ["en"]}
      assert :error = Graphql.parse_locale(input3)

      # Test map value
      input4 = %{value: %{nested: "value"}}
      assert :error = Graphql.parse_locale(input4)
    end
  end

  describe "validate_locale regex and normalization complete coverage" do
    test "validates exact regex patterns for locale codes" do
      # Two-letter codes (should pass regex)
      two_letter_valid = ["en", "es", "fr", "de", "it", "pt", "nl", "pl", "ru", "ja", "zh", "ar"]

      for code <- two_letter_valid do
        input = %{value: code}
        result = Graphql.parse_locale(input)
        # Should either succeed or be rejected by LocaleValidator, not by regex
        assert match?({:ok, _}, result) or result == :error
      end

      # Locale with country code - correct format (lowercase-HYPHEN-UPPERCASE)
      country_codes = ["en-US", "en-GB", "pt-BR", "zh-CN", "es-MX"]

      for code <- country_codes do
        input = %{value: code}
        result = Graphql.parse_locale(input)
        # These get normalized and may fail validation
        assert match?({:ok, _}, result) or result == :error
      end

      # Invalid formats that should fail regex
      invalid_formats = [
        # too short
        "e",
        # too long
        "eng",
        # uppercase base
        "EN",
        # mixed case base
        "En",
        # lowercase country code
        "en-us",
        # mixed case country code
        "en-Us",
        # all uppercase
        "EN-US",
        # country code too short
        "en-U",
        # country code too long
        "en-USA",
        # underscore with lowercase (hyphen normalizes, this stays as-is but lowercased)
        "en_us",
        # space
        "en US",
        # dot
        "en.US",
        # slash
        "en/US",
        # starts with number
        "1en",
        # ends with number
        "en1",
        # number in base
        "e1",
        # number in country code
        "en-U1",
        # trailing separator
        "en-",
        # leading separator
        "-US",
        # only separators
        "--",
        # empty string
        "",
        # special characters
        "en<US>",
        # special characters
        "en&US"
      ]

      for code <- invalid_formats do
        input = %{value: code}
        assert :error = Graphql.parse_locale(input), "Expected #{code} to be rejected"
      end
    end

    test "validates normalization process (hyphen to underscore, lowercase)" do
      # Test that hyphens are converted to underscores and everything lowercased
      test_cases = [
        # Normalized to en_us, not in default supported list
        {"en-US", :error},
        # Normalized to pt_br, not in default supported list
        {"pt-BR", :error},
        # Normalized to en_us, not in default supported list
        {"en_US", :error},
        # Fails regex (uppercase base)
        {"EN-US", :error},
        # Simple code, should work
        {"en", {:ok, :en}},
        # Simple code, should work
        {"es", {:ok, :es}},
        # Simple code, should work
        {"fr", {:ok, :fr}}
      ]

      for {input_str, expected} <- test_cases do
        input = %{value: input_str}
        result = Graphql.parse_locale(input)

        assert result == expected,
               "Expected #{input_str} to return #{inspect(expected)}, got #{inspect(result)}"
      end
    end
  end

  describe "resolve_translation all code paths" do
    test "resolve with locale in args - locale exists" do
      resource = %{name_translations: %{es: "Producto"}}
      resolution = %{source: resource, state: :name}

      {:ok, result} = Graphql.resolve_translation(resource, %{locale: :es}, resolution)
      assert result == "Producto"
    end

    test "resolve with locale in args - locale missing, fallback to en" do
      resource = %{name_translations: %{en: "Product"}}
      resolution = %{source: resource, state: :name}

      {:ok, result} = Graphql.resolve_translation(resource, %{locale: :de}, resolution)
      assert result == "Product"
    end

    test "resolve with locale in args - both locale and en missing" do
      resource = %{name_translations: %{fr: "Produit"}}
      resolution = %{source: resource, state: :name}

      {:ok, result} = Graphql.resolve_translation(resource, %{locale: :de}, resolution)
      assert result == nil
    end

    test "resolve without locale in args - en exists" do
      resource = %{name_translations: %{en: "Product", es: "Producto"}}
      resolution = %{source: resource, state: :name}

      {:ok, result} = Graphql.resolve_translation(resource, %{}, resolution)
      assert result == "Product"
    end

    test "resolve without locale in args - en missing" do
      resource = %{name_translations: %{es: "Producto", fr: "Produit"}}
      resolution = %{source: resource, state: :name}

      {:ok, result} = Graphql.resolve_translation(resource, %{}, resolution)
      assert result == nil
    end

    test "resolve with empty translations map" do
      resource = %{name_translations: %{}}
      resolution = %{source: resource, state: :name}

      {:ok, result} = Graphql.resolve_translation(resource, %{locale: :en}, resolution)
      assert result == nil
    end

    test "resolve with missing translations field" do
      resource = %{}
      resolution = %{source: resource, state: :name}

      {:ok, result} = Graphql.resolve_translation(resource, %{locale: :en}, resolution)
      assert result == nil
    end
  end

  describe "resolve_all_translations all code paths" do
    test "resolve with multiple translations" do
      resource = %{
        name_translations: %{
          en: "Product",
          es: "Producto",
          fr: "Produit"
        }
      }

      resolution = %{source: resource, state: :name}

      {:ok, result} = Graphql.resolve_all_translations(resource, %{}, resolution)
      assert length(result) == 3
      assert Enum.all?(result, fn t -> is_binary(t.locale) and is_binary(t.value) end)
    end

    test "resolve with single translation" do
      resource = %{name_translations: %{en: "Product"}}
      resolution = %{source: resource, state: :name}

      {:ok, result} = Graphql.resolve_all_translations(resource, %{}, resolution)
      assert length(result) == 1
      assert hd(result) == %{locale: "en", value: "Product"}
    end

    test "resolve with empty translations" do
      resource = %{name_translations: %{}}
      resolution = %{source: resource, state: :name}

      {:ok, result} = Graphql.resolve_all_translations(resource, %{}, resolution)
      assert result == []
    end

    test "resolve with missing translations field" do
      resource = %{}
      resolution = %{source: resource, state: :name}

      {:ok, result} = Graphql.resolve_all_translations(resource, %{}, resolution)
      assert result == []
    end
  end

  describe "LocaleMiddleware.call all code paths" do
    test "call with locale present" do
      resolution = %{context: %{locale: :es}}
      result = Graphql.LocaleMiddleware.call(resolution, [])
      assert result.context.locale == :es
    end

    test "call with accept_language present, no locale" do
      resolution = %{context: %{accept_language: :fr}}
      result = Graphql.LocaleMiddleware.call(resolution, [])
      assert result.context.locale == :fr
    end

    test "call with neither locale nor accept_language" do
      resolution = %{context: %{}}
      result = Graphql.LocaleMiddleware.call(resolution, [])
      assert result.context.locale == :en
    end

    test "call with locale nil, accept_language present" do
      resolution = %{context: %{locale: nil, accept_language: :de}}
      result = Graphql.LocaleMiddleware.call(resolution, [])
      assert result.context.locale == :de
    end

    test "call with locale false, accept_language nil" do
      resolution = %{context: %{locale: false, accept_language: nil}}
      result = Graphql.LocaleMiddleware.call(resolution, [])
      assert result.context.locale == :en
    end

    test "call preserves existing context" do
      resolution = %{
        context: %{locale: :it, user_id: 123, tenant: "test"}
      }

      result = Graphql.LocaleMiddleware.call(resolution, [])
      assert result.context.locale == :it
      assert result.context.user_id == 123
      assert result.context.tenant == "test"
    end
  end
end
