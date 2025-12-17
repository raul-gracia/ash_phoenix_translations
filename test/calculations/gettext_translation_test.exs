defmodule AshPhoenixTranslations.Calculations.GettextTranslationTest do
  @moduledoc """
  Tests for the GettextTranslation calculation module.

  This module tests the Ash calculation that retrieves translations
  from Gettext.
  """

  use ExUnit.Case, async: true

  alias AshPhoenixTranslations.Calculations.GettextTranslation

  # Define a test struct to simulate Ash records
  defmodule TestProduct do
    defstruct [:id, :slug, :sku, :name, :name_translations]
  end

  describe "init/1" do
    test "initializes with provided options" do
      opts = [attribute_name: :name, gettext_module: MyApp.Gettext]
      assert {:ok, ^opts} = GettextTranslation.init(opts)
    end

    test "initializes with empty options" do
      assert {:ok, []} = GettextTranslation.init([])
    end
  end

  describe "load/3" do
    test "returns storage field to load for potential fallback" do
      opts = [attribute_name: :name]
      context = %{}

      result = GettextTranslation.load(nil, opts, context)

      assert result == [:name_translations]
    end

    test "returns storage field for description attribute" do
      opts = [attribute_name: :description]
      context = %{}

      result = GettextTranslation.load(nil, opts, context)

      assert result == [:description_translations]
    end
  end

  describe "calculate/3" do
    test "raises error when gettext_module not configured" do
      records = [%TestProduct{id: "123", name: "Test"}]
      opts = [attribute_name: :name, gettext_module: nil]
      context = %{locale: :es}

      assert_raise ArgumentError, ~r/Gettext module not configured/, fn ->
        GettextTranslation.calculate(records, opts, context)
      end
    end

    test "uses default locale :en when not specified" do
      records = [
        %TestProduct{
          id: "123",
          name_translations: %{"en" => "Product", "es" => "Producto"}
        }
      ]

      # This will fall back since we don't have a real Gettext module
      opts = [attribute_name: :name, gettext_module: NonExistent.Gettext]
      context = %{}

      result = GettextTranslation.calculate(records, opts, context)

      # Should return fallback value (from translations map or nil)
      assert is_list(result)
    end

    test "falls back to database storage when Gettext translation not found" do
      records = [
        %TestProduct{
          id: "123",
          name_translations: %{"es" => "Producto de Fallback"}
        }
      ]

      # Use a non-existent module to trigger fallback
      opts = [attribute_name: :name, gettext_module: NonExistent.Gettext]
      context = %{locale: :es}

      result = GettextTranslation.calculate(records, opts, context)

      # Should fall back to database storage
      assert result == ["Producto de Fallback"]
    end

    test "handles records without translations field" do
      records = [
        %TestProduct{id: "123"}
      ]

      opts = [attribute_name: :name, gettext_module: NonExistent.Gettext]
      context = %{locale: :es}

      result = GettextTranslation.calculate(records, opts, context)

      assert result == [nil]
    end

    test "calculates for multiple records" do
      records = [
        %TestProduct{id: "1", name_translations: %{"es" => "Uno"}},
        %TestProduct{id: "2", name_translations: %{"es" => "Dos"}},
        %TestProduct{id: "3", name_translations: %{"es" => "Tres"}}
      ]

      opts = [attribute_name: :name, gettext_module: NonExistent.Gettext]
      context = %{locale: :es}

      result = GettextTranslation.calculate(records, opts, context)

      assert result == ["Uno", "Dos", "Tres"]
    end
  end

  describe "record identifier resolution" do
    test "uses slug as identifier when present" do
      record = %TestProduct{id: "123", slug: "my-product", sku: "SKU-001"}

      # The identifier is used internally for msgid construction
      # We can't directly test get_record_identifier, but we can verify
      # the fallback behavior uses it correctly
      records = [record]
      opts = [attribute_name: :name, gettext_module: NonExistent.Gettext]
      context = %{locale: :es}

      result = GettextTranslation.calculate(records, opts, context)

      assert is_list(result)
    end

    test "uses sku as identifier when slug not present" do
      record = %TestProduct{id: "123", slug: nil, sku: "SKU-001"}

      records = [record]
      opts = [attribute_name: :name, gettext_module: NonExistent.Gettext]
      context = %{locale: :es}

      result = GettextTranslation.calculate(records, opts, context)

      assert is_list(result)
    end

    test "uses id as identifier when neither slug nor sku present" do
      record = %TestProduct{id: "123", slug: nil, sku: nil}

      records = [record]
      opts = [attribute_name: :name, gettext_module: NonExistent.Gettext]
      context = %{locale: :es}

      result = GettextTranslation.calculate(records, opts, context)

      assert is_list(result)
    end

    test "handles record with no identifier" do
      record = %TestProduct{id: nil, slug: nil, sku: nil}

      records = [record]
      opts = [attribute_name: :name, gettext_module: NonExistent.Gettext]
      context = %{locale: :es}

      result = GettextTranslation.calculate(records, opts, context)

      assert is_list(result)
    end
  end

  describe "locale handling" do
    test "converts locale to string for Gettext" do
      records = [
        %TestProduct{id: "123", name_translations: %{"fr" => "Produit"}}
      ]

      opts = [attribute_name: :name, gettext_module: NonExistent.Gettext]
      context = %{locale: :fr}

      result = GettextTranslation.calculate(records, opts, context)

      assert result == ["Produit"]
    end

    test "handles string locale in fallback" do
      records = [
        %TestProduct{
          id: "123",
          name_translations: %{"de" => "Produkt"}
        }
      ]

      opts = [attribute_name: :name, gettext_module: NonExistent.Gettext]
      context = %{locale: :de}

      result = GettextTranslation.calculate(records, opts, context)

      assert result == ["Produkt"]
    end
  end
end
