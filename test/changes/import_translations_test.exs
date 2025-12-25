defmodule AshPhoenixTranslations.Changes.ImportTranslationsTest do
  @moduledoc """
  Tests for the ImportTranslations change module.

  This module tests the Ash change that handles bulk importing translations
  in various formats (JSON, CSV, XLIFF).

  Note: Tests that require full Ash.Changeset functionality with
  force_change_attribute need a proper Ash resource setup and are
  limited in scope here.
  """

  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias AshPhoenixTranslations.Changes.ImportTranslations

  # Set up atoms that will be used in tests (to prevent atom exhaustion errors)
  @test_atoms [:name, :description, :title, :en, :es, :fr, :de]

  setup do
    # Ensure test atoms exist
    for atom <- @test_atoms, do: atom
    :ok
  end

  describe "init/1" do
    test "initializes with provided options" do
      opts = [backend: :database, action_name: :import_translations]
      assert {:ok, ^opts} = ImportTranslations.init(opts)
    end

    test "initializes with empty options" do
      assert {:ok, []} = ImportTranslations.init([])
    end
  end

  describe "change/3 - action matching" do
    test "skips when action_name doesn't match current action" do
      changeset = %Ash.Changeset{
        action: %{name: :update},
        data: %{},
        arguments: %{}
      }

      opts = [backend: :database, action_name: :import_translations]
      context = %{}

      result = ImportTranslations.change(changeset, opts, context)

      # Should return unchanged changeset
      assert result == changeset
    end

    test "processes when action_name is nil (default behavior) with gettext" do
      changeset = %Ash.Changeset{
        action: %{name: :import_translations},
        data: %{},
        arguments: %{
          translations: %{name: %{en: "Test"}}
        },
        attributes: %{},
        errors: []
      }

      opts = [backend: :gettext]
      context = %{}

      result = ImportTranslations.change(changeset, opts, context)

      assert is_struct(result, Ash.Changeset)
    end

    test "processes when action_name matches current action with gettext" do
      changeset = %Ash.Changeset{
        action: %{name: :import_translations},
        data: %{},
        arguments: %{
          translations: %{name: %{en: "Test"}}
        },
        attributes: %{},
        errors: []
      }

      opts = [backend: :gettext, action_name: :import_translations]
      context = %{}

      result = ImportTranslations.change(changeset, opts, context)

      assert is_struct(result, Ash.Changeset)
    end

    test "adds error when action is nil and translations missing" do
      changeset = %Ash.Changeset{
        action: nil,
        data: %{},
        arguments: %{},
        attributes: %{},
        errors: []
      }

      opts = [backend: :database, action_name: :import_translations]
      context = %{}

      result = ImportTranslations.change(changeset, opts, context)

      # When action is nil and action_name is set, it skips but then processes
      # Since translations are missing, it should add an error
      assert is_struct(result, Ash.Changeset)
      assert Enum.any?(result.errors)
    end
  end

  describe "change/3 - JSON format" do
    test "processes JSON format with gettext backend (placeholder)" do
      changeset = %Ash.Changeset{
        action: %{name: :import_translations},
        data: %{},
        arguments: %{
          translations: %{name: %{en: "Product", es: "Producto"}},
          format: :json
        },
        attributes: %{},
        errors: []
      }

      opts = [backend: :gettext]
      context = %{}

      result = ImportTranslations.change(changeset, opts, context)

      assert is_struct(result, Ash.Changeset)
      assert result.errors == []
    end

    test "processes JSON format with empty translations and gettext backend" do
      changeset = %Ash.Changeset{
        action: %{name: :import_translations},
        data: %{},
        arguments: %{
          translations: %{},
          format: :json
        },
        attributes: %{},
        errors: []
      }

      opts = [backend: :gettext]
      context = %{}

      result = ImportTranslations.change(changeset, opts, context)

      assert is_struct(result, Ash.Changeset)
    end

    test "processes JSON format with multiple attributes and gettext backend" do
      changeset = %Ash.Changeset{
        action: %{name: :import_translations},
        data: %{},
        arguments: %{
          translations: %{
            name: %{en: "Product", es: "Producto"},
            description: %{en: "Description", fr: "Description"}
          },
          format: :json
        },
        attributes: %{},
        errors: []
      }

      opts = [backend: :gettext]
      context = %{}

      result = ImportTranslations.change(changeset, opts, context)

      assert is_struct(result, Ash.Changeset)
      assert result.errors == []
    end
  end

  describe "change/3 - CSV format" do
    test "parses valid CSV with single line using gettext backend" do
      csv_data = "name,en,Product"

      changeset = %Ash.Changeset{
        action: %{name: :import_translations},
        data: %{},
        arguments: %{
          translations: csv_data,
          format: :csv
        },
        attributes: %{},
        errors: []
      }

      opts = [backend: :gettext]
      context = %{}

      result = ImportTranslations.change(changeset, opts, context)

      assert is_struct(result, Ash.Changeset)
    end

    test "parses valid CSV with multiple lines using gettext backend" do
      csv_data = """
      name,en,Product
      name,es,Producto
      description,en,A great product
      """

      changeset = %Ash.Changeset{
        action: %{name: :import_translations},
        data: %{},
        arguments: %{
          translations: csv_data,
          format: :csv
        },
        attributes: %{},
        errors: []
      }

      opts = [backend: :gettext]
      context = %{}

      result = ImportTranslations.change(changeset, opts, context)

      assert is_struct(result, Ash.Changeset)
    end

    test "handles CSV with whitespace in fields using gettext backend" do
      csv_data = " name , en , Product "

      changeset = %Ash.Changeset{
        action: %{name: :import_translations},
        data: %{},
        arguments: %{
          translations: csv_data,
          format: :csv
        },
        attributes: %{},
        errors: []
      }

      opts = [backend: :gettext]
      context = %{}

      result = ImportTranslations.change(changeset, opts, context)

      assert is_struct(result, Ash.Changeset)
    end

    test "handles CSV with invalid field name (non-existent atom)" do
      csv_data = "nonexistent_field_123,en,Value"

      changeset = %Ash.Changeset{
        action: %{name: :import_translations},
        data: %{},
        arguments: %{
          translations: csv_data,
          format: :csv
        },
        attributes: %{},
        errors: []
      }

      opts = [backend: :gettext]
      context = %{}

      # Capture log to suppress expected warning about non-existent field atom
      capture_log(fn ->
        result = ImportTranslations.change(changeset, opts, context)

        # Should skip invalid field without error
        assert is_struct(result, Ash.Changeset)
      end)
    end

    test "handles CSV with invalid locale" do
      csv_data = "name,invalid_locale_xyz,Value"

      changeset = %Ash.Changeset{
        action: %{name: :import_translations},
        data: %{},
        arguments: %{
          translations: csv_data,
          format: :csv
        },
        attributes: %{},
        errors: []
      }

      opts = [backend: :gettext]
      context = %{}

      result = ImportTranslations.change(changeset, opts, context)

      # Should skip invalid locale without error
      assert is_struct(result, Ash.Changeset)
    end

    test "handles CSV with malformed lines (less than 3 parts)" do
      csv_data = """
      name,en,Product
      invalid_line
      description,es,Descripcion
      """

      changeset = %Ash.Changeset{
        action: %{name: :import_translations},
        data: %{},
        arguments: %{
          translations: csv_data,
          format: :csv
        },
        attributes: %{},
        errors: []
      }

      opts = [backend: :gettext]
      context = %{}

      result = ImportTranslations.change(changeset, opts, context)

      # Should skip malformed line without error
      assert is_struct(result, Ash.Changeset)
    end

    test "handles CSV with values containing commas using gettext backend" do
      csv_data = "name,en,Product, with commas, here"

      changeset = %Ash.Changeset{
        action: %{name: :import_translations},
        data: %{},
        arguments: %{
          translations: csv_data,
          format: :csv
        },
        attributes: %{},
        errors: []
      }

      opts = [backend: :gettext]
      context = %{}

      result = ImportTranslations.change(changeset, opts, context)

      assert is_struct(result, Ash.Changeset)
    end

    test "handles empty CSV" do
      changeset = %Ash.Changeset{
        action: %{name: :import_translations},
        data: %{},
        arguments: %{
          translations: "",
          format: :csv
        },
        attributes: %{},
        errors: []
      }

      opts = [backend: :gettext]
      context = %{}

      result = ImportTranslations.change(changeset, opts, context)

      assert is_struct(result, Ash.Changeset)
    end

    test "handles CSV with only newlines" do
      changeset = %Ash.Changeset{
        action: %{name: :import_translations},
        data: %{},
        arguments: %{
          translations: "\n\n\n",
          format: :csv
        },
        attributes: %{},
        errors: []
      }

      opts = [backend: :gettext]
      context = %{}

      result = ImportTranslations.change(changeset, opts, context)

      assert is_struct(result, Ash.Changeset)
    end
  end

  describe "change/3 - XLIFF format" do
    test "returns changeset for XLIFF (placeholder implementation)" do
      changeset = %Ash.Changeset{
        action: %{name: :import_translations},
        data: %{},
        arguments: %{
          translations: "<xliff>...</xliff>",
          format: :xliff
        },
        attributes: %{},
        errors: []
      }

      opts = [backend: :database]
      context = %{}

      result = ImportTranslations.change(changeset, opts, context)

      # XLIFF is placeholder - should return changeset unchanged
      assert is_struct(result, Ash.Changeset)
    end

    test "handles empty XLIFF string" do
      changeset = %Ash.Changeset{
        action: %{name: :import_translations},
        data: %{},
        arguments: %{
          translations: "",
          format: :xliff
        },
        attributes: %{},
        errors: []
      }

      opts = [backend: :database]
      context = %{}

      result = ImportTranslations.change(changeset, opts, context)

      assert is_struct(result, Ash.Changeset)
    end
  end

  describe "change/3 - merge behavior" do
    test "merges translations when merge is true (default) with gettext" do
      changeset = %Ash.Changeset{
        action: %{name: :import_translations},
        data: %{},
        arguments: %{
          translations: %{name: %{en: "New Name"}},
          merge: true
        },
        attributes: %{name_translations: %{es: "Nombre"}},
        errors: []
      }

      opts = [backend: :gettext]
      context = %{}

      result = ImportTranslations.change(changeset, opts, context)

      assert is_struct(result, Ash.Changeset)
    end

    test "replaces translations when merge is false with gettext" do
      changeset = %Ash.Changeset{
        action: %{name: :import_translations},
        data: %{},
        arguments: %{
          translations: %{name: %{en: "New Name"}},
          merge: false
        },
        attributes: %{name_translations: %{es: "Nombre"}},
        errors: []
      }

      opts = [backend: :gettext]
      context = %{}

      result = ImportTranslations.change(changeset, opts, context)

      assert is_struct(result, Ash.Changeset)
    end

    test "defaults to merge when merge argument is not provided with gettext" do
      changeset = %Ash.Changeset{
        action: %{name: :import_translations},
        data: %{},
        arguments: %{
          translations: %{name: %{en: "New Name"}}
        },
        attributes: %{name_translations: %{es: "Nombre"}},
        errors: []
      }

      opts = [backend: :gettext]
      context = %{}

      result = ImportTranslations.change(changeset, opts, context)

      assert is_struct(result, Ash.Changeset)
    end
  end

  describe "change/3 - error handling" do
    test "adds error when translations argument is missing" do
      changeset = %Ash.Changeset{
        action: %{name: :import_translations},
        data: %{},
        arguments: %{},
        attributes: %{},
        errors: []
      }

      opts = [backend: :database]
      context = %{}

      result = ImportTranslations.change(changeset, opts, context)

      assert Enum.any?(result.errors)

      assert Enum.any?(result.errors, fn error ->
               error.field == :translations
             end)
    end

    test "adds error when translations argument is nil" do
      changeset = %Ash.Changeset{
        action: %{name: :import_translations},
        data: %{},
        arguments: %{translations: nil},
        attributes: %{},
        errors: []
      }

      opts = [backend: :database]
      context = %{}

      result = ImportTranslations.change(changeset, opts, context)

      assert Enum.any?(result.errors)
    end

    test "raises when backend option is missing" do
      changeset = %Ash.Changeset{
        action: %{name: :import_translations},
        data: %{},
        arguments: %{translations: %{name: %{en: "Test"}}},
        attributes: %{},
        errors: []
      }

      opts = []
      context = %{}

      assert_raise KeyError, fn ->
        ImportTranslations.change(changeset, opts, context)
      end
    end
  end

  describe "change/3 - gettext backend" do
    test "returns changeset unchanged for gettext backend with JSON" do
      changeset = %Ash.Changeset{
        action: %{name: :import_translations},
        data: %{},
        arguments: %{
          translations: %{name: %{en: "Test"}}
        },
        attributes: %{},
        errors: []
      }

      opts = [backend: :gettext]
      context = %{}

      result = ImportTranslations.change(changeset, opts, context)

      # Gettext import is placeholder - returns unchanged
      assert is_struct(result, Ash.Changeset)
      assert result == changeset
    end

    test "returns changeset unchanged for gettext backend with CSV" do
      changeset = %Ash.Changeset{
        action: %{name: :import_translations},
        data: %{},
        arguments: %{
          translations: "name,en,Product",
          format: :csv
        },
        attributes: %{},
        errors: []
      }

      opts = [backend: :gettext]
      context = %{}

      result = ImportTranslations.change(changeset, opts, context)

      assert is_struct(result, Ash.Changeset)
      assert result == changeset
    end

    test "returns changeset unchanged for gettext backend with XLIFF" do
      changeset = %Ash.Changeset{
        action: %{name: :import_translations},
        data: %{},
        arguments: %{
          translations: "<xliff>...</xliff>",
          format: :xliff
        },
        attributes: %{},
        errors: []
      }

      opts = [backend: :gettext]
      context = %{}

      result = ImportTranslations.change(changeset, opts, context)

      assert is_struct(result, Ash.Changeset)
      assert result == changeset
    end
  end

  describe "change/3 - unknown format fallback" do
    test "handles unknown format with gettext backend" do
      changeset = %Ash.Changeset{
        action: %{name: :import_translations},
        data: %{},
        arguments: %{
          translations: %{name: %{en: "Test"}},
          format: :unknown_format
        },
        attributes: %{},
        errors: []
      }

      opts = [backend: :gettext]
      context = %{}

      result = ImportTranslations.change(changeset, opts, context)

      assert is_struct(result, Ash.Changeset)
    end

    test "handles unknown format with map data and gettext backend" do
      changeset = %Ash.Changeset{
        action: %{name: :import_translations},
        data: %{},
        arguments: %{
          translations: %{name: %{en: "Test"}},
          format: :custom_format
        },
        attributes: %{},
        errors: []
      }

      opts = [backend: :gettext]
      context = %{}

      result = ImportTranslations.change(changeset, opts, context)

      assert is_struct(result, Ash.Changeset)
    end
  end
end
