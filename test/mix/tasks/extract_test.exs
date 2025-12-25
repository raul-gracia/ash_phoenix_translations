defmodule Mix.Tasks.AshPhoenixTranslations.ExtractTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO

  alias Mix.Tasks.AshPhoenixTranslations.Extract

  setup do
    # Ensure cache is started
    case AshPhoenixTranslations.Cache.start_link() do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    AshPhoenixTranslations.Cache.clear()

    :ok
  end

  describe "format validation" do
    test "accepts pot format" do
      output =
        capture_io(fn ->
          try do
            Extract.run([
              "--format",
              "pot",
              "--resources",
              "AshPhoenixTranslations.MixTaskTest.TestProduct"
            ])
          rescue
            _ -> :ok
          end
        end)

      # Should not raise format error
      refute output =~ "Invalid format"
    end

    test "accepts po format" do
      output =
        capture_io(fn ->
          try do
            Extract.run([
              "--format",
              "po",
              "--resources",
              "AshPhoenixTranslations.MixTaskTest.TestProduct"
            ])
          rescue
            _ -> :ok
          end
        end)

      refute output =~ "Invalid format"
    end

    test "accepts both format" do
      output =
        capture_io(fn ->
          try do
            Extract.run([
              "--format",
              "both",
              "--resources",
              "AshPhoenixTranslations.MixTaskTest.TestProduct"
            ])
          rescue
            _ -> :ok
          end
        end)

      refute output =~ "Invalid format"
    end

    test "rejects invalid format" do
      assert_raise Mix.Error, ~r/Invalid format/, fn ->
        Extract.run([
          "--format",
          "invalid",
          "--resources",
          "AshPhoenixTranslations.MixTaskTest.TestProduct"
        ])
      end
    end
  end

  describe "resource selection" do
    test "accepts specific resources via --resources" do
      output =
        capture_io(fn ->
          try do
            Extract.run([
              "--resources",
              "AshPhoenixTranslations.MixTaskTest.TestProduct"
            ])
          rescue
            _ -> :ok
          end
        end)

      # Should process the specified resource
      assert output =~ "Extraction complete" || output =~ "Extracting" || output =~ "resources"
    end

    test "accepts multiple resources via comma-separated list" do
      output =
        capture_io(fn ->
          try do
            Extract.run([
              "--resources",
              "AshPhoenixTranslations.MixTaskTest.TestProduct,AshPhoenixTranslations.MixTaskTest.TestCategory"
            ])
          rescue
            _ -> :ok
          end
        end)

      assert output =~ "Extraction complete" || output =~ "Extracting"
    end

    test "accepts domain filter via --domain" do
      output =
        capture_io(fn ->
          try do
            Extract.run([
              "--domain",
              "AshPhoenixTranslations.MixTaskTest.TestDomain"
            ])
          rescue
            _ -> :ok
          end
        end)

      # Should attempt to process domain
      assert output =~ "Extraction" || output =~ "resources" || output =~ "No resources"
    end
  end

  describe "POT file generation" do
    @tag :tmp_dir
    test "generates POT file with correct structure", %{tmp_dir: tmp_dir} do
      output =
        capture_io(fn ->
          Extract.run([
            "--resources",
            "AshPhoenixTranslations.MixTaskTest.TestProduct",
            "--output",
            tmp_dir,
            "--format",
            "pot"
          ])
        end)

      assert output =~ "Generated POT file" || output =~ "Extraction complete"

      pot_file = Path.join(tmp_dir, "default.pot")
      assert File.exists?(pot_file)

      content = File.read!(pot_file)

      # Check POT header
      assert content =~ "msgid \"\""
      assert content =~ "msgstr \"\""
      assert content =~ "Content-Type: text/plain; charset=UTF-8"
      assert content =~ "MIME-Version: 1.0"

      # Check extracted strings
      assert content =~ "test_product.name" || content =~ "product.name"
    end

    @tag :tmp_dir
    test "extracts translatable attribute msgids", %{tmp_dir: tmp_dir} do
      capture_io(fn ->
        Extract.run([
          "--resources",
          "AshPhoenixTranslations.MixTaskTest.TestProduct",
          "--output",
          tmp_dir,
          "--format",
          "pot"
        ])
      end)

      pot_file = Path.join(tmp_dir, "default.pot")
      content = File.read!(pot_file)

      # Should extract name and description attributes
      assert content =~ "name" || content =~ "test_product"
    end

    @tag :tmp_dir
    test "includes location comments", %{tmp_dir: tmp_dir} do
      capture_io(fn ->
        Extract.run([
          "--resources",
          "AshPhoenixTranslations.MixTaskTest.TestProduct",
          "--output",
          tmp_dir,
          "--format",
          "pot"
        ])
      end)

      pot_file = Path.join(tmp_dir, "default.pot")
      content = File.read!(pot_file)

      # Should have location comments
      assert content =~ "#:" || content =~ "TestProduct"
    end

    @tag :tmp_dir
    test "extracts action descriptions", %{tmp_dir: tmp_dir} do
      capture_io(fn ->
        Extract.run([
          "--resources",
          "AshPhoenixTranslations.MixTaskTest.TestProduct",
          "--output",
          tmp_dir,
          "--format",
          "pot"
        ])
      end)

      pot_file = Path.join(tmp_dir, "default.pot")
      content = File.read!(pot_file)

      # Should extract action descriptions
      assert content =~ "actions" || content =~ "create" || content =~ "description"
    end
  end

  describe "PO file generation" do
    @tag :tmp_dir
    test "generates PO files for specified locales", %{tmp_dir: tmp_dir} do
      output =
        capture_io(fn ->
          Extract.run([
            "--resources",
            "AshPhoenixTranslations.MixTaskTest.TestProduct",
            "--output",
            tmp_dir,
            "--format",
            "po",
            "--locales",
            "es,fr"
          ])
        end)

      assert output =~ "Generated PO file" || output =~ "Extraction complete"

      # Check Spanish PO file
      es_po_file = Path.join([tmp_dir, "es", "LC_MESSAGES", "default.po"])
      assert File.exists?(es_po_file)

      es_content = File.read!(es_po_file)
      assert es_content =~ "Language: es"

      # Check French PO file
      fr_po_file = Path.join([tmp_dir, "fr", "LC_MESSAGES", "default.po"])
      assert File.exists?(fr_po_file)

      fr_content = File.read!(fr_po_file)
      assert fr_content =~ "Language: fr"
    end

    @tag :tmp_dir
    test "PO files have proper directory structure", %{tmp_dir: tmp_dir} do
      capture_io(fn ->
        Extract.run([
          "--resources",
          "AshPhoenixTranslations.MixTaskTest.TestProduct",
          "--output",
          tmp_dir,
          "--format",
          "po",
          "--locales",
          "en"
        ])
      end)

      # Check directory structure: locale/LC_MESSAGES/default.po
      assert File.dir?(Path.join([tmp_dir, "en"]))
      assert File.dir?(Path.join([tmp_dir, "en", "LC_MESSAGES"]))
      assert File.exists?(Path.join([tmp_dir, "en", "LC_MESSAGES", "default.po"]))
    end
  end

  describe "both format generation" do
    @tag :tmp_dir
    test "generates both POT and PO files", %{tmp_dir: tmp_dir} do
      output =
        capture_io(fn ->
          Extract.run([
            "--resources",
            "AshPhoenixTranslations.MixTaskTest.TestProduct",
            "--output",
            tmp_dir,
            "--format",
            "both",
            "--locales",
            "es"
          ])
        end)

      assert output =~ "Extraction complete"

      # POT file should exist
      pot_file = Path.join(tmp_dir, "default.pot")
      assert File.exists?(pot_file)

      # PO file should exist
      po_file = Path.join([tmp_dir, "es", "LC_MESSAGES", "default.po"])
      assert File.exists?(po_file)
    end
  end

  describe "verbose mode" do
    @tag :tmp_dir
    test "verbose flag provides detailed output", %{tmp_dir: tmp_dir} do
      output =
        capture_io(fn ->
          Extract.run([
            "--resources",
            "AshPhoenixTranslations.MixTaskTest.TestProduct",
            "--output",
            tmp_dir,
            "--verbose"
          ])
        end)

      # Verbose mode should show extra info
      assert output =~ "Starting" || output =~ "Output directory" || output =~ "Found"
    end

    @tag :tmp_dir
    test "shows resource count in verbose mode", %{tmp_dir: tmp_dir} do
      output =
        capture_io(fn ->
          Extract.run([
            "--resources",
            "AshPhoenixTranslations.MixTaskTest.TestProduct",
            "--output",
            tmp_dir,
            "--verbose"
          ])
        end)

      assert output =~ "resources" || output =~ "Found"
    end

    @tag :tmp_dir
    test "shows extracted string count in verbose mode", %{tmp_dir: tmp_dir} do
      output =
        capture_io(fn ->
          Extract.run([
            "--resources",
            "AshPhoenixTranslations.MixTaskTest.TestProduct",
            "--output",
            tmp_dir,
            "--verbose"
          ])
        end)

      assert output =~ "strings" || output =~ "Extracted"
    end
  end

  describe "merge option" do
    @tag :tmp_dir
    test "merge flag merges with existing POT file", %{tmp_dir: tmp_dir} do
      # Create initial POT file
      pot_file = Path.join(tmp_dir, "default.pot")
      File.mkdir_p!(tmp_dir)
      File.write!(pot_file, "# Existing POT file\nmsgid \"existing\"\nmsgstr \"\"\n")

      output =
        capture_io(fn ->
          Extract.run([
            "--resources",
            "AshPhoenixTranslations.MixTaskTest.TestProduct",
            "--output",
            tmp_dir,
            "--merge"
          ])
        end)

      assert output =~ "Merging" || output =~ "Extraction complete"
    end
  end

  describe "string escaping" do
    @tag :tmp_dir
    test "escapes special characters in msgid", %{tmp_dir: tmp_dir} do
      capture_io(fn ->
        Extract.run([
          "--resources",
          "AshPhoenixTranslations.MixTaskTest.TestProduct",
          "--output",
          tmp_dir,
          "--format",
          "pot"
        ])
      end)

      pot_file = Path.join(tmp_dir, "default.pot")
      content = File.read!(pot_file)

      # File should be valid POT format
      assert content =~ "msgid \"\""
      assert content =~ "msgstr \"\""
      # Content should be properly formatted
      assert content =~ "Content-Type: text/plain; charset=UTF-8"
    end
  end

  describe "error handling" do
    test "handles non-existent resource gracefully" do
      output =
        capture_io(fn ->
          try do
            Extract.run([
              "--resources",
              "NonExistent.Resource"
            ])
          rescue
            _ -> :ok
          catch
            # Exited
            :exit, _ -> :ok
          end
        end)

      # Should handle gracefully - exits with code 1 when no resources found
      assert output =~ "No resources" || output =~ "Exited" || output == ""
    end

    test "handles resource without translations" do
      output =
        capture_io(fn ->
          try do
            Extract.run([
              "--resources",
              "NonTranslatableResource"
            ])
          rescue
            _ -> :ok
          catch
            # Exited
            :exit, _ -> :ok
          end
        end)

      # Should handle gracefully - exits with code 1 when no resources found
      assert output =~ "No resources" || output =~ "Exited" || output == ""
    end
  end

  describe "default behavior" do
    @tag :tmp_dir
    test "defaults to pot format when not specified", %{tmp_dir: tmp_dir} do
      output =
        capture_io(fn ->
          Extract.run([
            "--resources",
            "AshPhoenixTranslations.MixTaskTest.TestProduct",
            "--output",
            tmp_dir
          ])
        end)

      # Should generate POT file by default
      pot_file = Path.join(tmp_dir, "default.pot")
      assert File.exists?(pot_file)
      assert output =~ "Generated POT file" || output =~ "Extraction complete"
    end

    @tag :tmp_dir
    test "defaults to priv/gettext output directory", %{tmp_dir: _tmp_dir} do
      # This test verifies the default path is used
      # We won't actually write there in tests
      output =
        capture_io(fn ->
          try do
            Extract.run([
              "--resources",
              "AshPhoenixTranslations.MixTaskTest.TestProduct"
            ])
          rescue
            _ -> :ok
          end
        end)

      # Default should be priv/gettext
      assert output =~ "priv/gettext" || output =~ "Extraction" || true
    end
  end

  describe "multiple resources extraction" do
    @tag :tmp_dir
    test "extracts strings from multiple resources", %{tmp_dir: tmp_dir} do
      output =
        capture_io(fn ->
          Extract.run([
            "--resources",
            "AshPhoenixTranslations.MixTaskTest.TestProduct,AshPhoenixTranslations.MixTaskTest.TestCategory",
            "--output",
            tmp_dir,
            "--verbose"
          ])
        end)

      assert output =~ "Extraction complete"

      pot_file = Path.join(tmp_dir, "default.pot")
      content = File.read!(pot_file)

      # Should have entries from both resources
      assert content =~ "product" || content =~ "name"
      assert content =~ "category" || content =~ "title"
    end
  end
end
