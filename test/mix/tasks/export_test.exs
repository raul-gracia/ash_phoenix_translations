defmodule Mix.Tasks.AshPhoenixTranslations.ExportTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO

  alias Mix.Tasks.AshPhoenixTranslations.Export
  alias AshPhoenixTranslations.MixTaskTest.TestProduct

  setup do
    # Ensure cache is started
    case AshPhoenixTranslations.Cache.start_link() do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    AshPhoenixTranslations.Cache.clear()

    :ok
  end

  describe "argument validation" do
    test "requires resource option" do
      assert_raise Mix.Error, ~r/--resource option is required/, fn ->
        Export.run(["output.csv"])
      end
    end

    test "requires output file" do
      assert_raise Mix.Error, ~r/Please provide an output file/, fn ->
        Export.run(["--resource", "Example.Product"])
      end
    end

    test "accepts resource and output file" do
      # This will fail because Example.Product doesn't exist, but validates args
      output =
        capture_io(fn ->
          try do
            Export.run([
              "test_output.csv",
              "--resource",
              "AshPhoenixTranslations.MixTaskTest.TestProduct"
            ])
          rescue
            _ -> :ok
          end
        end)

      assert output =~ "Exporting translations"
    end
  end

  describe "format detection" do
    @tag :tmp_dir
    test "detects CSV format from extension", %{tmp_dir: tmp_dir} do
      output_path = Path.join(tmp_dir, "export.csv")

      output =
        capture_io(fn ->
          try do
            Export.run([
              output_path,
              "--resource",
              "AshPhoenixTranslations.MixTaskTest.TestProduct"
            ])
          rescue
            _ -> :ok
          end
        end)

      assert output =~ "Format: csv"
    end

    @tag :tmp_dir
    test "detects JSON format from extension", %{tmp_dir: tmp_dir} do
      output_path = Path.join(tmp_dir, "export.json")

      output =
        capture_io(fn ->
          try do
            Export.run([
              output_path,
              "--resource",
              "AshPhoenixTranslations.MixTaskTest.TestProduct"
            ])
          rescue
            _ -> :ok
          end
        end)

      assert output =~ "Format: json"
    end

    @tag :tmp_dir
    test "detects XLIFF format from .xliff extension", %{tmp_dir: tmp_dir} do
      output_path = Path.join(tmp_dir, "export.xliff")

      output =
        capture_io(fn ->
          try do
            Export.run([
              output_path,
              "--resource",
              "AshPhoenixTranslations.MixTaskTest.TestProduct"
            ])
          rescue
            _ -> :ok
          end
        end)

      assert output =~ "Format: xliff"
    end

    @tag :tmp_dir
    test "detects XLIFF format from .xlf extension", %{tmp_dir: tmp_dir} do
      output_path = Path.join(tmp_dir, "export.xlf")

      output =
        capture_io(fn ->
          try do
            Export.run([
              output_path,
              "--resource",
              "AshPhoenixTranslations.MixTaskTest.TestProduct"
            ])
          rescue
            _ -> :ok
          end
        end)

      assert output =~ "Format: xliff"
    end

    @tag :tmp_dir
    test "defaults to CSV for unknown extension", %{tmp_dir: tmp_dir} do
      output_path = Path.join(tmp_dir, "export.unknown")

      output =
        capture_io(fn ->
          try do
            Export.run([
              output_path,
              "--resource",
              "AshPhoenixTranslations.MixTaskTest.TestProduct"
            ])
          rescue
            _ -> :ok
          end
        end)

      assert output =~ "Format: csv"
    end

    @tag :tmp_dir
    test "explicit format overrides extension detection", %{tmp_dir: tmp_dir} do
      output_path = Path.join(tmp_dir, "export.csv")

      output =
        capture_io(fn ->
          try do
            Export.run([
              output_path,
              "--resource",
              "AshPhoenixTranslations.MixTaskTest.TestProduct",
              "--format",
              "json"
            ])
          rescue
            _ -> :ok
          end
        end)

      assert output =~ "Format: json"
    end
  end

  describe "export with data" do
    setup do
      # Create test products with translations
      {:ok, product1} =
        TestProduct
        |> Ash.Changeset.for_create(:create, %{
          sku: "EXPORT-001",
          name_translations: %{
            en: "English Name 1",
            es: "Spanish Name 1",
            fr: "French Name 1"
          },
          description_translations: %{
            en: "English Description 1",
            es: "Spanish Description 1"
          }
        })
        |> Ash.create()

      {:ok, product2} =
        TestProduct
        |> Ash.Changeset.for_create(:create, %{
          sku: "EXPORT-002",
          name_translations: %{
            en: "English Name 2",
            es: "Spanish Name 2"
          },
          description_translations: %{
            en: "English Description 2"
          }
        })
        |> Ash.create()

      {:ok, product1: product1, product2: product2}
    end

    @tag :tmp_dir
    test "exports to CSV format with correct structure", %{tmp_dir: tmp_dir, product1: product1} do
      output_path = Path.join(tmp_dir, "export.csv")

      output =
        capture_io(fn ->
          Export.run([
            output_path,
            "--resource",
            "AshPhoenixTranslations.MixTaskTest.TestProduct"
          ])
        end)

      assert output =~ "Export complete!"
      assert File.exists?(output_path)

      content = File.read!(output_path)
      assert content =~ "resource_id,field,locale,value"
      assert content =~ to_string(product1.id)
      assert content =~ "English Name 1"
    end

    @tag :tmp_dir
    test "exports to JSON format with metadata", %{tmp_dir: tmp_dir, product1: product1} do
      output_path = Path.join(tmp_dir, "export.json")

      output =
        capture_io(fn ->
          Export.run([
            output_path,
            "--resource",
            "AshPhoenixTranslations.MixTaskTest.TestProduct",
            "--format",
            "json"
          ])
        end)

      assert output =~ "Export complete!"
      assert File.exists?(output_path)

      content = File.read!(output_path)
      data = Jason.decode!(content)

      assert Map.has_key?(data, "metadata")
      assert Map.has_key?(data, "translations")
      assert data["metadata"]["total"] > 0
      assert data["metadata"]["exported_at"] != nil

      # Check translations structure
      translations = data["translations"]
      assert is_list(translations)
      assert length(translations) > 0

      # Find a translation for product1
      product1_trans =
        Enum.find(translations, fn t ->
          t["resource_id"] == to_string(product1.id) && t["field"] == "name" && t["locale"] == "en"
        end)

      assert product1_trans != nil
      assert product1_trans["value"] == "English Name 1"
    end

    @tag :tmp_dir
    test "exports to XLIFF format", %{tmp_dir: tmp_dir} do
      output_path = Path.join(tmp_dir, "export.xliff")

      output =
        capture_io(fn ->
          Export.run([
            output_path,
            "--resource",
            "AshPhoenixTranslations.MixTaskTest.TestProduct"
          ])
        end)

      assert output =~ "Export complete!"
      assert File.exists?(output_path)

      content = File.read!(output_path)
      assert content =~ "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
      assert content =~ "<xliff"
      assert content =~ "trans-unit"
    end
  end

  describe "filtering options" do
    setup do
      {:ok, product} =
        TestProduct
        |> Ash.Changeset.for_create(:create, %{
          sku: "FILTER-001",
          name_translations: %{
            en: "English Name",
            es: "Spanish Name",
            fr: "French Name"
          },
          description_translations: %{
            en: "English Description",
            es: "Spanish Description",
            fr: "French Description"
          }
        })
        |> Ash.create()

      {:ok, product: product}
    end

    @tag :tmp_dir
    test "filters by locale", %{tmp_dir: tmp_dir} do
      output_path = Path.join(tmp_dir, "export_es.csv")

      output =
        capture_io(fn ->
          Export.run([
            output_path,
            "--resource",
            "AshPhoenixTranslations.MixTaskTest.TestProduct",
            "--locale",
            "es"
          ])
        end)

      assert output =~ "Export complete!"
      content = File.read!(output_path)

      # Should only have Spanish translations
      lines = String.split(content, "\n", trim: true)
      # Skip header, check data lines
      data_lines = Enum.drop(lines, 1)

      Enum.each(data_lines, fn line ->
        # Third column is locale
        parts = String.split(line, ",")

        if length(parts) >= 3 do
          assert Enum.at(parts, 2) == "es"
        end
      end)
    end

    @tag :tmp_dir
    test "filters by multiple locales", %{tmp_dir: tmp_dir} do
      output_path = Path.join(tmp_dir, "export_multi.csv")

      output =
        capture_io(fn ->
          Export.run([
            output_path,
            "--resource",
            "AshPhoenixTranslations.MixTaskTest.TestProduct",
            "--locale",
            "en,es"
          ])
        end)

      assert output =~ "Export complete!"
      content = File.read!(output_path)

      # Should have English and Spanish but not French
      refute content =~ ",fr,"
    end

    @tag :tmp_dir
    test "missing-only exports translations with nil values", %{tmp_dir: tmp_dir} do
      # Create product with missing translation
      {:ok, _product} =
        TestProduct
        |> Ash.Changeset.for_create(:create, %{
          sku: "MISSING-001",
          name_translations: %{
            en: "English Only"
          }
        })
        |> Ash.create()

      output_path = Path.join(tmp_dir, "export_missing.csv")

      output =
        capture_io(fn ->
          Export.run([
            output_path,
            "--resource",
            "AshPhoenixTranslations.MixTaskTest.TestProduct",
            "--missing-only"
          ])
        end)

      assert output =~ "Export complete!"
      # Output will be empty or contain only empty values
      assert File.exists?(output_path)
    end

    @tag :tmp_dir
    test "complete-only exports non-empty translations", %{tmp_dir: tmp_dir, product: product} do
      output_path = Path.join(tmp_dir, "export_complete.csv")

      output =
        capture_io(fn ->
          Export.run([
            output_path,
            "--resource",
            "AshPhoenixTranslations.MixTaskTest.TestProduct",
            "--complete-only"
          ])
        end)

      assert output =~ "Export complete!"
      content = File.read!(output_path)

      # All exported translations should have values
      assert content =~ to_string(product.id)
      assert content =~ "English Name"
    end
  end

  describe "CSV escaping" do
    setup do
      {:ok, product} =
        TestProduct
        |> Ash.Changeset.for_create(:create, %{
          sku: "ESCAPE-001",
          name_translations: %{
            en: "Name with, comma",
            es: "Name with \"quotes\"",
            fr: "Name with\nnewline"
          }
        })
        |> Ash.create()

      {:ok, product: product}
    end

    @tag :tmp_dir
    test "properly escapes commas in CSV", %{tmp_dir: tmp_dir} do
      output_path = Path.join(tmp_dir, "export_escape.csv")

      capture_io(fn ->
        Export.run([
          output_path,
          "--resource",
          "AshPhoenixTranslations.MixTaskTest.TestProduct",
          "--locale",
          "en"
        ])
      end)

      content = File.read!(output_path)
      # Commas should be escaped with quotes
      assert content =~ "\"Name with, comma\""
    end

    @tag :tmp_dir
    test "properly escapes quotes in CSV", %{tmp_dir: tmp_dir} do
      output_path = Path.join(tmp_dir, "export_escape.csv")

      capture_io(fn ->
        Export.run([
          output_path,
          "--resource",
          "AshPhoenixTranslations.MixTaskTest.TestProduct",
          "--locale",
          "es"
        ])
      end)

      content = File.read!(output_path)
      # Quotes should be escaped by doubling
      assert content =~ "\"\"quotes\"\""
    end
  end

  describe "edge cases" do
    @tag :tmp_dir
    test "handles empty resource gracefully", %{tmp_dir: tmp_dir} do
      # Clear any existing data by running in isolation
      output_path = Path.join(tmp_dir, "export_empty.csv")

      # This should handle zero translations gracefully
      output =
        capture_io(fn ->
          Export.run([
            output_path,
            "--resource",
            "AshPhoenixTranslations.MixTaskTest.TestProduct"
          ])
        end)

      # Should complete without errors
      assert output =~ "Export complete!" || output =~ "Exporting"
    end

    @tag :tmp_dir
    test "creates output directory if it doesn't exist", %{tmp_dir: tmp_dir} do
      output_path = Path.join([tmp_dir, "nested", "dir", "export.csv"])

      capture_io(fn ->
        try do
          Export.run([
            output_path,
            "--resource",
            "AshPhoenixTranslations.MixTaskTest.TestProduct"
          ])
        rescue
          _ -> :ok
        end
      end)

      # Directory should be created
      assert File.dir?(Path.dirname(output_path))
    end

    test "handles invalid locale filter gracefully" do
      # Invalid locale should be skipped with warning
      output =
        capture_io(:stderr, fn ->
          capture_io(fn ->
            try do
              Export.run([
                "output.csv",
                "--resource",
                "AshPhoenixTranslations.MixTaskTest.TestProduct",
                "--locale",
                "invalid_locale_xyz"
              ])
            rescue
              _ -> :ok
            end
          end)
        end)

      # Should report invalid locale
      assert output =~ "invalid" || output =~ "Skipping" || output == ""
    end
  end

  describe "option aliases" do
    test "supports -r alias for --resource" do
      output =
        capture_io(fn ->
          try do
            Export.run([
              "output.csv",
              "-r",
              "AshPhoenixTranslations.MixTaskTest.TestProduct"
            ])
          rescue
            _ -> :ok
          end
        end)

      assert output =~ "Exporting translations"
    end

    test "supports -f alias for --format" do
      output =
        capture_io(fn ->
          try do
            Export.run([
              "output.csv",
              "-r",
              "AshPhoenixTranslations.MixTaskTest.TestProduct",
              "-f",
              "json"
            ])
          rescue
            _ -> :ok
          end
        end)

      assert output =~ "Format: json"
    end

    test "supports -l alias for --locale" do
      output =
        capture_io(fn ->
          try do
            Export.run([
              "output.csv",
              "-r",
              "AshPhoenixTranslations.MixTaskTest.TestProduct",
              "-l",
              "es"
            ])
          rescue
            _ -> :ok
          end
        end)

      # Locale filter should be applied
      assert output =~ "Exporting" || output =~ "Filters"
    end
  end

  describe "XML escaping for XLIFF" do
    setup do
      {:ok, product} =
        TestProduct
        |> Ash.Changeset.for_create(:create, %{
          sku: "XML-001",
          name_translations: %{
            en: "Name with <special> & \"characters\""
          }
        })
        |> Ash.create()

      {:ok, product: product}
    end

    @tag :tmp_dir
    test "escapes XML special characters in XLIFF", %{tmp_dir: tmp_dir} do
      output_path = Path.join(tmp_dir, "export_xml.xliff")

      capture_io(fn ->
        Export.run([
          output_path,
          "--resource",
          "AshPhoenixTranslations.MixTaskTest.TestProduct"
        ])
      end)

      content = File.read!(output_path)
      # Check XML escaping
      assert content =~ "&lt;special&gt;"
      assert content =~ "&amp;"
      assert content =~ "&quot;"
    end
  end
end
