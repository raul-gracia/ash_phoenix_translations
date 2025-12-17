defmodule AshPhoenixTranslations.Calculations.AllTranslationsTest do
  @moduledoc """
  Tests for the AllTranslations calculation module.

  This module tests the Ash calculation that returns all translations
  for an attribute across all configured locales.
  """

  use ExUnit.Case, async: true

  alias AshPhoenixTranslations.Calculations.AllTranslations

  # Define a test struct to simulate Ash records
  defmodule TestProduct do
    defstruct [:id, :name, :name_translations, :description_translations]
  end

  describe "init/1" do
    test "initializes with provided options" do
      opts = [attribute_name: :name, backend: :database, locales: [:en, :es, :fr]]
      assert {:ok, ^opts} = AllTranslations.init(opts)
    end

    test "initializes with empty options" do
      assert {:ok, []} = AllTranslations.init([])
    end
  end

  describe "load/3 for database backend" do
    test "returns storage field to load" do
      opts = [attribute_name: :name, backend: :database]
      context = %{}

      result = AllTranslations.load(nil, opts, context)

      assert result == [:name_translations]
    end

    test "returns storage field for description attribute" do
      opts = [attribute_name: :description, backend: :database]
      context = %{}

      result = AllTranslations.load(nil, opts, context)

      assert result == [:description_translations]
    end
  end

  describe "load/3 for gettext backend" do
    test "returns empty list since Gettext doesn't need preloading" do
      opts = [attribute_name: :name, backend: :gettext]
      context = %{}

      result = AllTranslations.load(nil, opts, context)

      assert result == []
    end
  end

  describe "calculate/3 for database backend" do
    test "returns all translations from storage field" do
      records = [
        %TestProduct{
          name_translations: %{
            en: "Product",
            es: "Producto",
            fr: "Produit"
          }
        }
      ]

      opts = [attribute_name: :name, backend: :database, locales: [:en, :es, :fr]]
      context = %{}

      result = AllTranslations.calculate(records, opts, context)

      assert result == [%{en: "Product", es: "Producto", fr: "Produit"}]
    end

    test "returns empty map when no translations" do
      records = [
        %TestProduct{
          name_translations: %{}
        }
      ]

      opts = [attribute_name: :name, backend: :database, locales: [:en, :es]]
      context = %{}

      result = AllTranslations.calculate(records, opts, context)

      assert result == [%{}]
    end

    test "handles missing translations field" do
      records = [
        %TestProduct{}
      ]

      opts = [attribute_name: :name, backend: :database, locales: [:en, :es]]
      context = %{}

      result = AllTranslations.calculate(records, opts, context)

      # Map.get with default %{} returns nil when the field doesn't exist
      # since the struct doesn't have name_translations key
      assert result == [nil]
    end

    test "returns partial translations when not all locales present" do
      records = [
        %TestProduct{
          name_translations: %{
            en: "Product"
          }
        }
      ]

      opts = [attribute_name: :name, backend: :database, locales: [:en, :es, :fr]]
      context = %{}

      result = AllTranslations.calculate(records, opts, context)

      assert result == [%{en: "Product"}]
    end

    test "calculates for multiple records" do
      records = [
        %TestProduct{name_translations: %{en: "One", es: "Uno"}},
        %TestProduct{name_translations: %{en: "Two", es: "Dos"}},
        %TestProduct{name_translations: %{en: "Three", es: "Tres"}}
      ]

      opts = [attribute_name: :name, backend: :database, locales: [:en, :es]]
      context = %{}

      result = AllTranslations.calculate(records, opts, context)

      assert result == [
               %{en: "One", es: "Uno"},
               %{en: "Two", es: "Dos"},
               %{en: "Three", es: "Tres"}
             ]
    end
  end

  describe "calculate/3 for gettext backend" do
    test "returns empty map when gettext_module not configured" do
      records = [
        %TestProduct{id: "123"}
      ]

      opts = [attribute_name: :name, backend: :gettext, locales: [:en, :es]]
      context = %{}

      # Without Application.put_env for gettext_module, should return empty
      result = AllTranslations.calculate(records, opts, context)

      assert result == [%{}]
    end
  end

  describe "expression/2 for database backend" do
    test "generates expression for database backend" do
      opts = [attribute_name: :name, backend: :database]
      context = %{}

      result = AllTranslations.expression(opts, context)

      # Should return an Ash expression referencing the storage field
      assert result != :runtime
    end
  end

  describe "expression/2 for non-database backends" do
    test "returns :runtime for gettext backend" do
      opts = [attribute_name: :name, backend: :gettext]
      context = %{}

      result = AllTranslations.expression(opts, context)

      assert result == :runtime
    end

    test "returns :runtime for unknown backend" do
      opts = [attribute_name: :name, backend: :unknown]
      context = %{}

      result = AllTranslations.expression(opts, context)

      assert result == :runtime
    end
  end

  describe "edge cases" do
    test "handles nil values in translations map" do
      records = [
        %TestProduct{
          name_translations: %{
            en: "Product",
            es: nil,
            fr: "Produit"
          }
        }
      ]

      opts = [attribute_name: :name, backend: :database, locales: [:en, :es, :fr]]
      context = %{}

      result = AllTranslations.calculate(records, opts, context)

      # Should preserve nil values
      assert result == [%{en: "Product", es: nil, fr: "Produit"}]
    end

    test "handles empty string values in translations map" do
      records = [
        %TestProduct{
          name_translations: %{
            en: "Product",
            es: "",
            fr: "Produit"
          }
        }
      ]

      opts = [attribute_name: :name, backend: :database, locales: [:en, :es, :fr]]
      context = %{}

      result = AllTranslations.calculate(records, opts, context)

      # Should preserve empty strings
      assert result == [%{en: "Product", es: "", fr: "Produit"}]
    end

    test "handles mixed key types (atoms and strings)" do
      # The storage might have string keys in some cases
      records = [
        %TestProduct{
          name_translations: %{
            "en" => "Product",
            "es" => "Producto"
          }
        }
      ]

      opts = [attribute_name: :name, backend: :database, locales: [:en, :es]]
      context = %{}

      result = AllTranslations.calculate(records, opts, context)

      # Should return whatever is in the storage
      assert result == [%{"en" => "Product", "es" => "Producto"}]
    end
  end
end
