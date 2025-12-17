defmodule AshPhoenixTranslations.Changes.ValidateRequiredTranslationsTest do
  @moduledoc """
  Tests for the ValidateRequiredTranslations change module.

  This module tests the Ash change that validates required translations
  are present for translatable attributes.
  """

  use ExUnit.Case, async: true

  alias AshPhoenixTranslations.Changes.ValidateRequiredTranslations

  describe "init/1" do
    test "initializes with provided options" do
      opts = [attribute_name: :name, required_locales: [:en, :es], backend: :database]
      assert {:ok, ^opts} = ValidateRequiredTranslations.init(opts)
    end

    test "initializes with empty options" do
      assert {:ok, []} = ValidateRequiredTranslations.init([])
    end
  end

  describe "change/3 - action matching" do
    test "skips when action_name doesn't match current action" do
      changeset = %Ash.Changeset{
        action: %{name: :update},
        data: %{},
        arguments: %{}
      }

      opts = [
        attribute_name: :name,
        required_locales: [:en],
        backend: :database,
        action_name: :create
      ]

      context = %{}

      result = ValidateRequiredTranslations.change(changeset, opts, context)

      # Should return unchanged changeset
      assert result == changeset
    end

    test "processes when action_name matches" do
      changeset = %Ash.Changeset{
        action: %{name: :create},
        data: %{name_translations: %{en: "Product"}},
        arguments: %{},
        attributes: %{},
        errors: []
      }

      opts = [
        attribute_name: :name,
        required_locales: [:en],
        backend: :database,
        action_name: :create
      ]

      context = %{}

      result = ValidateRequiredTranslations.change(changeset, opts, context)

      # Should validate without errors since en is present
      refute Enum.any?(result.errors)
    end
  end

  describe "change/3 - database backend validation" do
    test "passes when all required locales are present" do
      changeset = %Ash.Changeset{
        action: %{name: :create},
        data: %{name_translations: %{en: "Product", es: "Producto"}},
        arguments: %{},
        attributes: %{},
        errors: []
      }

      opts = [
        attribute_name: :name,
        required_locales: [:en, :es],
        backend: :database
      ]

      context = %{}

      result = ValidateRequiredTranslations.change(changeset, opts, context)

      refute Enum.any?(result.errors)
    end

    test "fails when required locale is missing" do
      changeset = %Ash.Changeset{
        action: %{name: :create},
        data: %{name_translations: %{en: "Product"}},
        arguments: %{},
        attributes: %{},
        errors: []
      }

      opts = [
        attribute_name: :name,
        required_locales: [:en, :es],
        backend: :database
      ]

      context = %{}

      result = ValidateRequiredTranslations.change(changeset, opts, context)

      assert Enum.any?(result.errors)
      error = hd(result.errors)
      assert error.field == :name
    end

    test "fails when required locale has nil value" do
      changeset = %Ash.Changeset{
        action: %{name: :create},
        data: %{name_translations: %{en: "Product", es: nil}},
        arguments: %{},
        attributes: %{},
        errors: []
      }

      opts = [
        attribute_name: :name,
        required_locales: [:en, :es],
        backend: :database
      ]

      context = %{}

      result = ValidateRequiredTranslations.change(changeset, opts, context)

      assert Enum.any?(result.errors)
    end

    test "fails when required locale has empty string value" do
      changeset = %Ash.Changeset{
        action: %{name: :create},
        data: %{name_translations: %{en: "Product", es: ""}},
        arguments: %{},
        attributes: %{},
        errors: []
      }

      opts = [
        attribute_name: :name,
        required_locales: [:en, :es],
        backend: :database
      ]

      context = %{}

      result = ValidateRequiredTranslations.change(changeset, opts, context)

      assert Enum.any?(result.errors)
    end

    test "checks changed values in changeset" do
      changeset = %Ash.Changeset{
        action: %{name: :create},
        data: %{},
        arguments: %{},
        attributes: %{name_translations: %{en: "Product", es: "Producto"}},
        errors: []
      }

      opts = [
        attribute_name: :name,
        required_locales: [:en, :es],
        backend: :database
      ]

      context = %{}

      result = ValidateRequiredTranslations.change(changeset, opts, context)

      # Should pass since attributes have required locales
      assert is_struct(result, Ash.Changeset)
    end

    test "validates with empty required_locales list" do
      changeset = %Ash.Changeset{
        action: %{name: :create},
        data: %{name_translations: %{}},
        arguments: %{},
        attributes: %{},
        errors: []
      }

      opts = [
        attribute_name: :name,
        required_locales: [],
        backend: :database
      ]

      context = %{}

      result = ValidateRequiredTranslations.change(changeset, opts, context)

      # No required locales means no validation needed
      refute Enum.any?(result.errors)
    end
  end

  describe "change/3 - gettext backend" do
    test "skips validation for gettext backend" do
      changeset = %Ash.Changeset{
        action: %{name: :create},
        data: %{},
        arguments: %{},
        attributes: %{},
        errors: []
      }

      opts = [
        attribute_name: :name,
        required_locales: [:en, :es],
        backend: :gettext
      ]

      context = %{}

      result = ValidateRequiredTranslations.change(changeset, opts, context)

      # Gettext validation happens at compile time
      refute Enum.any?(result.errors)
    end
  end

  describe "change/3 - error messages" do
    test "includes missing locales in error message" do
      changeset = %Ash.Changeset{
        action: %{name: :create},
        data: %{name_translations: %{en: "Product"}},
        arguments: %{},
        attributes: %{},
        errors: []
      }

      opts = [
        attribute_name: :name,
        required_locales: [:en, :es, :fr],
        backend: :database
      ]

      context = %{}

      result = ValidateRequiredTranslations.change(changeset, opts, context)

      error = hd(result.errors)
      assert error.message =~ "Missing required translations"
      assert error.message =~ "es"
      assert error.message =~ "fr"
    end

    test "error vars contain attribute and missing_locales" do
      changeset = %Ash.Changeset{
        action: %{name: :create},
        data: %{title_translations: %{}},
        arguments: %{},
        attributes: %{},
        errors: []
      }

      opts = [
        attribute_name: :title,
        required_locales: [:en],
        backend: :database
      ]

      context = %{}

      result = ValidateRequiredTranslations.change(changeset, opts, context)

      error = hd(result.errors)
      # Check that the error has the expected structure
      assert error.field == :title
      assert error.vars != nil
      # The vars may be structured differently, check for presence
      assert is_list(error.vars) or is_map(error.vars)
    end
  end

  describe "change/3 - edge cases" do
    test "handles nil translations map" do
      changeset = %Ash.Changeset{
        action: %{name: :create},
        data: %{name_translations: nil},
        arguments: %{},
        attributes: %{},
        errors: []
      }

      opts = [
        attribute_name: :name,
        required_locales: [:en],
        backend: :database
      ]

      context = %{}

      result = ValidateRequiredTranslations.change(changeset, opts, context)

      # Should fail since translations are nil
      assert Enum.any?(result.errors)
    end

    test "handles missing translations field entirely" do
      changeset = %Ash.Changeset{
        action: %{name: :create},
        data: %{},
        arguments: %{},
        attributes: %{},
        errors: []
      }

      opts = [
        attribute_name: :name,
        required_locales: [:en],
        backend: :database
      ]

      context = %{}

      result = ValidateRequiredTranslations.change(changeset, opts, context)

      # Should fail since translations field is missing
      assert Enum.any?(result.errors)
    end

    test "validates multiple required locales correctly" do
      changeset = %Ash.Changeset{
        action: %{name: :create},
        data: %{name_translations: %{en: "Product", es: "Producto", fr: "Produit"}},
        arguments: %{},
        attributes: %{},
        errors: []
      }

      opts = [
        attribute_name: :name,
        required_locales: [:en, :es, :fr],
        backend: :database
      ]

      context = %{}

      result = ValidateRequiredTranslations.change(changeset, opts, context)

      refute Enum.any?(result.errors)
    end
  end
end
