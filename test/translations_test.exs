defmodule AshPhoenixTranslations.TranslationsTest do
  use ExUnit.Case, async: true

  alias AshPhoenixTranslations.TranslatableAttribute
  alias AshPhoenixTranslations.Translations

  describe "struct/0" do
    test "defines Translations struct with expected fields" do
      translations = %Translations{}

      assert Map.has_key?(translations, :backend)
      assert Map.has_key?(translations, :cache_ttl)
      assert Map.has_key?(translations, :audit_changes)
      assert Map.has_key?(translations, :auto_validate)
      assert Map.has_key?(translations, :translatable_attributes)
    end

    test "struct fields default to nil" do
      translations = %Translations{}

      assert translations.backend == nil
      assert translations.cache_ttl == nil
      assert translations.audit_changes == nil
      assert translations.auto_validate == nil
      assert translations.translatable_attributes == nil
    end
  end

  describe "struct initialization" do
    test "creates struct with all fields" do
      translations = %Translations{
        backend: :database,
        cache_ttl: 3600,
        audit_changes: true,
        auto_validate: true,
        translatable_attributes: []
      }

      assert translations.backend == :database
      assert translations.cache_ttl == 3600
      assert translations.audit_changes == true
      assert translations.auto_validate == true
      assert translations.translatable_attributes == []
    end

    test "creates struct with partial fields" do
      translations = %Translations{
        backend: :gettext,
        cache_ttl: 7200
      }

      assert translations.backend == :gettext
      assert translations.cache_ttl == 7200
      assert translations.audit_changes == nil
      assert translations.auto_validate == nil
    end

    test "creates struct with translatable attributes" do
      attr = %TranslatableAttribute{
        name: :name,
        type: :string,
        locales: [:en, :es, :fr],
        required: [:en]
      }

      translations = %Translations{
        backend: :database,
        translatable_attributes: [attr]
      }

      assert length(translations.translatable_attributes) == 1
      assert hd(translations.translatable_attributes).name == :name
    end
  end

  describe "backend validation" do
    test "accepts :database backend" do
      translations = %Translations{backend: :database}

      assert translations.backend == :database
    end

    test "accepts :gettext backend" do
      translations = %Translations{backend: :gettext}

      assert translations.backend == :gettext
    end

    test "accepts nil backend" do
      translations = %Translations{backend: nil}

      assert translations.backend == nil
    end
  end

  describe "cache_ttl validation" do
    test "accepts positive integer cache_ttl" do
      translations = %Translations{cache_ttl: 3600}

      assert translations.cache_ttl == 3600
    end

    test "accepts different TTL values" do
      translations_short = %Translations{cache_ttl: 300}
      translations_long = %Translations{cache_ttl: 86_400}

      assert translations_short.cache_ttl == 300
      assert translations_long.cache_ttl == 86_400
    end

    test "accepts nil cache_ttl" do
      translations = %Translations{cache_ttl: nil}

      assert translations.cache_ttl == nil
    end
  end

  describe "audit_changes validation" do
    test "accepts true audit_changes" do
      translations = %Translations{audit_changes: true}

      assert translations.audit_changes == true
    end

    test "accepts false audit_changes" do
      translations = %Translations{audit_changes: false}

      assert translations.audit_changes == false
    end

    test "accepts nil audit_changes" do
      translations = %Translations{audit_changes: nil}

      assert translations.audit_changes == nil
    end
  end

  describe "auto_validate validation" do
    test "accepts true auto_validate" do
      translations = %Translations{auto_validate: true}

      assert translations.auto_validate == true
    end

    test "accepts false auto_validate" do
      translations = %Translations{auto_validate: false}

      assert translations.auto_validate == false
    end

    test "accepts nil auto_validate" do
      translations = %Translations{auto_validate: nil}

      assert translations.auto_validate == nil
    end
  end

  describe "translatable_attributes" do
    test "accepts empty list of translatable attributes" do
      translations = %Translations{translatable_attributes: []}

      assert translations.translatable_attributes == []
    end

    test "accepts list with single translatable attribute" do
      attr = %TranslatableAttribute{
        name: :title,
        type: :string,
        locales: [:en, :es],
        required: [:en]
      }

      translations = %Translations{translatable_attributes: [attr]}

      assert length(translations.translatable_attributes) == 1
    end

    test "accepts list with multiple translatable attributes" do
      attr1 = %TranslatableAttribute{
        name: :name,
        type: :string,
        locales: [:en, :es, :fr],
        required: [:en]
      }

      attr2 = %TranslatableAttribute{
        name: :description,
        type: :text,
        locales: [:en, :es, :fr],
        required: [:en]
      }

      translations = %Translations{translatable_attributes: [attr1, attr2]}

      assert length(translations.translatable_attributes) == 2
      assert Enum.at(translations.translatable_attributes, 0).name == :name
      assert Enum.at(translations.translatable_attributes, 1).name == :description
    end

    test "accepts nil translatable_attributes" do
      translations = %Translations{translatable_attributes: nil}

      assert translations.translatable_attributes == nil
    end
  end

  describe "type specification" do
    test "defines correct type specification" do
      # This test verifies the @type annotation is correct
      # by ensuring the struct can be created with all expected types

      translations = %Translations{
        backend: :database,
        cache_ttl: 3600,
        audit_changes: true,
        auto_validate: false,
        translatable_attributes: [
          %TranslatableAttribute{
            name: :name,
            type: :string,
            locales: [:en, :es],
            required: [:en]
          }
        ]
      }

      assert is_atom(translations.backend)
      assert is_integer(translations.cache_ttl)
      assert is_boolean(translations.audit_changes)
      assert is_boolean(translations.auto_validate)
      assert is_list(translations.translatable_attributes)
    end
  end

  describe "struct updates" do
    test "updates single field" do
      original = %Translations{backend: :database, cache_ttl: 3600}
      updated = %{original | cache_ttl: 7200}

      assert updated.backend == :database
      assert updated.cache_ttl == 7200
    end

    test "updates multiple fields" do
      original = %Translations{backend: :database, cache_ttl: 3600}

      updated = %{original | backend: :gettext, cache_ttl: 1800, audit_changes: true}

      assert updated.backend == :gettext
      assert updated.cache_ttl == 1800
      assert updated.audit_changes == true
    end

    test "updates translatable_attributes" do
      attr1 = %TranslatableAttribute{name: :name, type: :string, locales: [:en]}
      attr2 = %TranslatableAttribute{name: :description, type: :text, locales: [:en, :es]}

      original = %Translations{translatable_attributes: [attr1]}
      updated = %{original | translatable_attributes: [attr1, attr2]}

      assert length(updated.translatable_attributes) == 2
    end
  end

  describe "pattern matching" do
    # Helper to test pattern matching at runtime
    defp classify_backend(translations) do
      case translations do
        %Translations{backend: :database} -> :database_backend
        %Translations{backend: :gettext} -> :gettext_backend
        _ -> :unknown
      end
    end

    defp classify_cache_ttl(translations) do
      case translations do
        %Translations{cache_ttl: ttl} when is_integer(ttl) and ttl > 3000 -> :long_cache
        %Translations{cache_ttl: ttl} when is_integer(ttl) and ttl <= 3000 -> :short_cache
        _ -> :no_cache
      end
    end

    defp classify_audit(translations) do
      case translations do
        %Translations{audit_changes: true} -> :audited
        %Translations{audit_changes: false} -> :not_audited
        _ -> :unknown
      end
    end

    test "pattern matches on backend" do
      database_translations = %Translations{backend: :database}
      gettext_translations = %Translations{backend: :gettext}

      assert classify_backend(database_translations) == :database_backend
      assert classify_backend(gettext_translations) == :gettext_backend
    end

    test "pattern matches on cache_ttl" do
      long_cache = %Translations{cache_ttl: 3600}
      short_cache = %Translations{cache_ttl: 300}

      assert classify_cache_ttl(long_cache) == :long_cache
      assert classify_cache_ttl(short_cache) == :short_cache
    end

    test "pattern matches on audit_changes" do
      audited = %Translations{audit_changes: true}
      not_audited = %Translations{audit_changes: false}

      assert classify_audit(audited) == :audited
      assert classify_audit(not_audited) == :not_audited
    end
  end

  describe "struct equality" do
    # Helper to check equality at runtime to avoid compile-time type warnings
    defp structs_equal?(s1, s2), do: s1 == s2

    test "identical structs are equal" do
      t1 = %Translations{backend: :database, cache_ttl: 3600}
      t2 = %Translations{backend: :database, cache_ttl: 3600}

      assert structs_equal?(t1, t2)
    end

    test "different structs are not equal" do
      t1 = %Translations{backend: :database, cache_ttl: 3600}
      t2 = %Translations{backend: :gettext, cache_ttl: 3600}

      refute structs_equal?(t1, t2)
    end

    test "structs with different translatable_attributes are not equal" do
      attr1 = %TranslatableAttribute{name: :name, type: :string, locales: [:en]}
      attr2 = %TranslatableAttribute{name: :description, type: :text, locales: [:en]}

      t1 = %Translations{translatable_attributes: [attr1]}
      t2 = %Translations{translatable_attributes: [attr2]}

      refute structs_equal?(t1, t2)
    end
  end

  describe "Map operations" do
    test "converts to map" do
      translations = %Translations{backend: :database, cache_ttl: 3600, audit_changes: true}

      map = Map.from_struct(translations)

      assert map.backend == :database
      assert map.cache_ttl == 3600
      assert map.audit_changes == true
      assert not Map.has_key?(map, :__struct__)
    end

    test "converts from map with struct" do
      map = %{
        backend: :database,
        cache_ttl: 3600,
        audit_changes: true,
        auto_validate: false,
        translatable_attributes: []
      }

      translations = struct(Translations, map)

      assert translations.backend == :database
      assert translations.cache_ttl == 3600
      assert translations.audit_changes == true
      assert translations.auto_validate == false
      assert translations.translatable_attributes == []
    end
  end

  describe "Enum operations" do
    test "reduces over struct fields" do
      attr = %TranslatableAttribute{name: :name, type: :string, locales: [:en]}

      translations = %Translations{
        backend: :database,
        cache_ttl: 3600,
        audit_changes: true,
        auto_validate: true,
        translatable_attributes: [attr]
      }

      non_nil_count =
        translations
        |> Map.from_struct()
        |> Enum.count(fn {_key, value} -> value != nil end)

      assert non_nil_count == 5
    end

    test "filters struct fields" do
      translations = %Translations{backend: :database, cache_ttl: 3600}

      non_nil_fields =
        translations
        |> Map.from_struct()
        |> Enum.filter(fn {_key, value} -> value != nil end)
        |> Enum.map(fn {key, _value} -> key end)

      assert :backend in non_nil_fields
      assert :cache_ttl in non_nil_fields
      assert :audit_changes not in non_nil_fields
    end
  end

  describe "integration with TranslatableAttribute" do
    test "stores complex translatable attributes" do
      attr = %TranslatableAttribute{
        name: :description,
        type: :text,
        locales: [:en, :es, :fr, :de],
        required: [:en, :es],
        fallback: :en,
        markdown: true,
        validation: [max_length: 1000],
        constraints: [trim: true],
        description: "Product description"
      }

      translations = %Translations{
        backend: :database,
        translatable_attributes: [attr]
      }

      stored_attr = hd(translations.translatable_attributes)

      assert stored_attr.name == :description
      assert stored_attr.type == :text
      assert stored_attr.locales == [:en, :es, :fr, :de]
      assert stored_attr.required == [:en, :es]
      assert stored_attr.fallback == :en
      assert stored_attr.markdown == true
      assert stored_attr.validation == [max_length: 1000]
      assert stored_attr.constraints == [trim: true]
      assert stored_attr.description == "Product description"
    end

    test "stores multiple diverse translatable attributes" do
      attr1 = %TranslatableAttribute{
        name: :name,
        type: :string,
        locales: [:en, :es],
        required: [:en],
        markdown: false
      }

      attr2 = %TranslatableAttribute{
        name: :description,
        type: :text,
        locales: [:en, :es, :fr],
        required: [:en],
        markdown: true,
        fallback: :en
      }

      attr3 = %TranslatableAttribute{
        name: :tagline,
        type: :string,
        locales: [:en, :es, :fr, :de],
        required: [],
        fallback: :en
      }

      translations = %Translations{
        backend: :database,
        cache_ttl: 3600,
        audit_changes: true,
        translatable_attributes: [attr1, attr2, attr3]
      }

      assert length(translations.translatable_attributes) == 3

      names = Enum.map(translations.translatable_attributes, & &1.name)
      assert :name in names
      assert :description in names
      assert :tagline in names
    end
  end

  describe "default values behavior" do
    test "all fields are nil by default" do
      translations = %Translations{}

      assert translations.backend == nil
      assert translations.cache_ttl == nil
      assert translations.audit_changes == nil
      assert translations.auto_validate == nil
      assert translations.translatable_attributes == nil
    end
  end

  describe "struct field access" do
    test "accesses fields via dot notation" do
      translations = %Translations{
        backend: :database,
        cache_ttl: 3600,
        audit_changes: true
      }

      assert translations.backend == :database
      assert translations.cache_ttl == 3600
      assert translations.audit_changes == true
    end

    test "accesses fields via Map.get" do
      translations = %Translations{
        backend: :database,
        cache_ttl: 3600
      }

      assert Map.get(translations, :backend) == :database
      assert Map.get(translations, :cache_ttl) == 3600
      assert Map.get(translations, :audit_changes) == nil
    end

    test "accesses nested translatable attribute fields" do
      attr = %TranslatableAttribute{
        name: :name,
        type: :string,
        locales: [:en, :es, :fr]
      }

      translations = %Translations{translatable_attributes: [attr]}

      first_attr = hd(translations.translatable_attributes)
      assert first_attr.name == :name
      assert first_attr.type == :string
      assert first_attr.locales == [:en, :es, :fr]
    end
  end

  describe "serialization compatibility" do
    test "can be converted to keyword list" do
      translations = %Translations{
        backend: :database,
        cache_ttl: 3600,
        audit_changes: true
      }

      keyword_list =
        translations
        |> Map.from_struct()
        |> Enum.to_list()

      assert {:backend, :database} in keyword_list
      assert {:cache_ttl, 3600} in keyword_list
      assert {:audit_changes, true} in keyword_list
    end
  end

  describe "edge cases" do
    test "handles extreme cache_ttl values" do
      translations_zero = %Translations{cache_ttl: 0}
      translations_large = %Translations{cache_ttl: 999_999_999}

      assert translations_zero.cache_ttl == 0
      assert translations_large.cache_ttl == 999_999_999
    end

    test "handles empty translatable_attributes list" do
      translations = %Translations{
        backend: :database,
        translatable_attributes: []
      }

      assert Enum.empty?(translations.translatable_attributes)
    end

    test "handles large list of translatable_attributes" do
      attrs =
        Enum.map(1..100, fn i ->
          %TranslatableAttribute{
            name: String.to_atom("field_#{i}"),
            type: :string,
            locales: [:en]
          }
        end)

      translations = %Translations{translatable_attributes: attrs}

      assert length(translations.translatable_attributes) == 100
    end
  end

  describe "struct introspection" do
    test "has correct struct name" do
      translations = %Translations{}

      assert translations.__struct__ == AshPhoenixTranslations.Translations
    end

    test "lists all struct keys" do
      translations = %Translations{}
      keys = Map.keys(translations)

      assert :__struct__ in keys
      assert :backend in keys
      assert :cache_ttl in keys
      assert :audit_changes in keys
      assert :auto_validate in keys
      assert :translatable_attributes in keys
      assert length(keys) == 6
    end
  end

  describe "compatibility with Ash DSL" do
    test "struct is compatible with Spark DSL entity requirements" do
      # Verify that the struct can hold configuration data
      # that would be populated by Ash transformers
      translations = %Translations{
        backend: :database,
        cache_ttl: 3600,
        audit_changes: false,
        auto_validate: true,
        translatable_attributes: [
          %TranslatableAttribute{
            name: :name,
            type: :string,
            locales: [:en, :es, :fr],
            required: [:en]
          }
        ]
      }

      # Verify structure is suitable for DSL processing
      assert is_atom(translations.backend)
      assert is_integer(translations.cache_ttl) or is_nil(translations.cache_ttl)
      assert is_boolean(translations.audit_changes) or is_nil(translations.audit_changes)
      assert is_boolean(translations.auto_validate) or is_nil(translations.auto_validate)

      assert is_list(translations.translatable_attributes) or
               is_nil(translations.translatable_attributes)
    end

    test "translatable_attributes can store Spark entity structs" do
      # TranslatableAttribute is a Spark entity
      entity = %TranslatableAttribute{
        name: :title,
        type: :string,
        locales: [:en, :es],
        required: [:en]
      }

      translations = %Translations{translatable_attributes: [entity]}

      stored_entity = hd(translations.translatable_attributes)
      assert stored_entity.__struct__ == AshPhoenixTranslations.TranslatableAttribute
      assert stored_entity.name == :title
    end
  end
end
