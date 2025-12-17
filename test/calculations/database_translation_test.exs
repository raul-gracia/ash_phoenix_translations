defmodule AshPhoenixTranslations.Calculations.DatabaseTranslationTest do
  @moduledoc """
  Tests for the DatabaseTranslation calculation module.

  This module tests the Ash calculation that retrieves translations
  from database storage (JSONB columns).
  """

  use ExUnit.Case, async: true

  alias AshPhoenixTranslations.Calculations.DatabaseTranslation

  describe "init/1" do
    test "initializes with provided options" do
      opts = [attribute_name: :name, fallback: :en]
      assert {:ok, ^opts} = DatabaseTranslation.init(opts)
    end

    test "initializes with empty options" do
      assert {:ok, []} = DatabaseTranslation.init([])
    end
  end

  describe "load/3" do
    test "returns storage field to load" do
      opts = [attribute_name: :name]
      context = %{}

      result = DatabaseTranslation.load(nil, opts, context)

      assert result == [:name_translations]
    end

    test "returns storage field for description attribute" do
      opts = [attribute_name: :description]
      context = %{}

      result = DatabaseTranslation.load(nil, opts, context)

      assert result == [:description_translations]
    end
  end

  describe "calculate/3" do
    test "returns translation for locale from context" do
      records = [
        %{
          name_translations: %{
            en: "Product",
            es: "Producto"
          }
        }
      ]

      opts = [attribute_name: :name]
      context = %{locale: :es}

      result = DatabaseTranslation.calculate(records, opts, context)

      assert result == ["Producto"]
    end

    test "returns translation for locale from source_context" do
      records = [
        %{
          name_translations: %{
            en: "Product",
            es: "Producto"
          }
        }
      ]

      opts = [attribute_name: :name]
      context = %{source_context: %{locale: :es}}

      result = DatabaseTranslation.calculate(records, opts, context)

      assert result == ["Producto"]
    end

    test "falls back to default locale when no locale in context" do
      records = [
        %{
          name_translations: %{
            en: "Product",
            es: "Producto"
          }
        }
      ]

      opts = [attribute_name: :name]
      context = %{}

      result = DatabaseTranslation.calculate(records, opts, context)

      # Should fall back to :en (default locale)
      assert result == ["Product"]
    end

    test "uses fallback option for missing translations" do
      records = [
        %{
          name_translations: %{
            en: "Product"
          }
        }
      ]

      opts = [attribute_name: :name, fallback: :en]
      context = %{locale: :de}

      result = DatabaseTranslation.calculate(records, opts, context)

      # Should fall back to English
      assert result == ["Product"]
    end

    test "handles empty translations map" do
      records = [
        %{
          name_translations: %{}
        }
      ]

      opts = [attribute_name: :name]
      context = %{locale: :es}

      result = DatabaseTranslation.calculate(records, opts, context)

      assert result == [nil]
    end

    test "handles missing translations field" do
      records = [
        %{}
      ]

      opts = [attribute_name: :name]
      context = %{locale: :es}

      result = DatabaseTranslation.calculate(records, opts, context)

      assert result == [nil]
    end

    test "calculates for multiple records" do
      records = [
        %{name_translations: %{es: "Producto 1"}},
        %{name_translations: %{es: "Producto 2"}},
        %{name_translations: %{es: "Producto 3"}}
      ]

      opts = [attribute_name: :name]
      context = %{locale: :es}

      result = DatabaseTranslation.calculate(records, opts, context)

      assert result == ["Producto 1", "Producto 2", "Producto 3"]
    end

    test "handles nil translations value in map" do
      records = [
        %{
          name_translations: %{
            en: "Product",
            es: nil
          }
        }
      ]

      opts = [attribute_name: :name]
      context = %{locale: :es}

      result = DatabaseTranslation.calculate(records, opts, context)

      # Fallback should handle nil values
      assert result == ["Product"]
    end
  end

  describe "expression/2" do
    test "generates SQL expression for locale extraction" do
      opts = [attribute_name: :name]
      context = %{locale: :es}

      result = DatabaseTranslation.expression(opts, context)

      # Should return an Ash expression struct
      assert is_struct(result, Ash.Query.Call)
    end

    test "uses default locale when not in context" do
      opts = [attribute_name: :name]
      context = %{}

      result = DatabaseTranslation.expression(opts, context)

      assert is_struct(result, Ash.Query.Call)
    end
  end

  describe "locale resolution priority" do
    test "prefers direct locale in context" do
      records = [
        %{
          name_translations: %{
            en: "Product",
            es: "Producto",
            fr: "Produit"
          }
        }
      ]

      opts = [attribute_name: :name]
      context = %{locale: :fr, source_context: %{locale: :es}}

      result = DatabaseTranslation.calculate(records, opts, context)

      assert result == ["Produit"]
    end

    test "uses source_context locale when direct locale missing" do
      records = [
        %{
          name_translations: %{
            en: "Product",
            es: "Producto"
          }
        }
      ]

      opts = [attribute_name: :name]
      context = %{source_context: %{locale: :es}}

      result = DatabaseTranslation.calculate(records, opts, context)

      assert result == ["Producto"]
    end
  end
end
