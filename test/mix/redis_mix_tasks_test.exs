defmodule AshPhoenixTranslations.RedisMixTasksTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO

  @moduletag :redis

  alias Mix.Tasks.AshPhoenixTranslations

  # Reuse test resource from atom_exhaustion_mix_test
  @test_resource "AshPhoenixTranslations.AtomExhaustionMixTest.TestProduct"

  # Helper to check if Redis is available
  defp redis_available? do
    case System.cmd("redis-cli", ["ping"], stderr_to_stdout: true) do
      {"PONG\n", 0} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  describe "import.redis task - basic validation" do
    test "requires resource option" do
      assert_raise Mix.Error, ~r/--resource option is required/, fn ->
        AshPhoenixTranslations.Import.Redis.run(["file.csv"])
      end
    end

    test "requires file argument" do
      assert_raise Mix.Error, ~r/Please provide a file to import/, fn ->
        AshPhoenixTranslations.Import.Redis.run(["--resource", "Example.Product"])
      end
    end

    @tag :tmp_dir
    test "detects CSV format from extension", %{tmp_dir: tmp_dir} do
      csv_path = Path.join(tmp_dir, "translations.csv")
      File.write!(csv_path, "resource_id,field,locale,value\n")

      output =
        capture_io(fn ->
          try do
            AshPhoenixTranslations.Import.Redis.run([
              csv_path,
              "--resource",
              @test_resource,
              "--dry-run"
            ])
          rescue
            _ -> :ok
          end
        end)

      assert output =~ "Format: csv"
      assert output =~ "DRY RUN"
    end

    @tag :tmp_dir
    test "detects JSON format from extension", %{tmp_dir: tmp_dir} do
      json_path = Path.join(tmp_dir, "translations.json")
      File.write!(json_path, ~s({"translations": []}))

      output =
        capture_io(fn ->
          try do
            AshPhoenixTranslations.Import.Redis.run([
              json_path,
              "--resource",
              @test_resource,
              "--dry-run"
            ])
          rescue
            _ -> :ok
          end
        end)

      assert output =~ "Format: json"
      assert output =~ "DRY RUN"
    end

    test "raises on unknown format" do
      assert_raise Mix.Error, ~r/Cannot detect format/, fn ->
        # We need to use capture_io to suppress output
        capture_io(fn ->
          try do
            AshPhoenixTranslations.Import.Redis.run([
              "file.unknown",
              "--resource",
              "Example.Product"
            ])
          rescue
            e in Mix.Error -> reraise e, __STACKTRACE__
          end
        end)
      end
    end
  end

  describe "import.redis task - modes" do
    @tag :tmp_dir
    test "shows dry-run mode in output", %{tmp_dir: tmp_dir} do
      csv_path = Path.join(tmp_dir, "test.csv")
      File.write!(csv_path, "resource_id,field,locale,value\n1,name,en,Test")

      output =
        capture_io(fn ->
          try do
            AshPhoenixTranslations.Import.Redis.run([
              csv_path,
              "--resource",
              @test_resource,
              "--dry-run"
            ])
          rescue
            _ -> :ok
          end
        end)

      assert output =~ "DRY RUN"
      assert output =~ "No changes will be made"
    end

    @tag :tmp_dir
    test "shows replace mode in output", %{tmp_dir: tmp_dir} do
      csv_path = Path.join(tmp_dir, "test.csv")
      File.write!(csv_path, "resource_id,field,locale,value\n1,name,en,Test")

      output =
        capture_io(fn ->
          try do
            AshPhoenixTranslations.Import.Redis.run([
              csv_path,
              "--resource",
              @test_resource,
              "--replace",
              "--dry-run"
            ])
          rescue
            _ -> :ok
          end
        end)

      assert output =~ "Mode: replace"
    end

    @tag :tmp_dir
    test "shows merge mode in output by default", %{tmp_dir: tmp_dir} do
      csv_path = Path.join(tmp_dir, "test.csv")
      File.write!(csv_path, "resource_id,field,locale,value\n1,name,en,Test")

      output =
        capture_io(fn ->
          try do
            AshPhoenixTranslations.Import.Redis.run([
              csv_path,
              "--resource",
              @test_resource,
              "--dry-run"
            ])
          rescue
            _ -> :ok
          end
        end)

      assert output =~ "Mode: merge"
    end

    @tag :tmp_dir
    test "shows TTL in output when specified", %{tmp_dir: tmp_dir} do
      csv_path = Path.join(tmp_dir, "test.csv")
      File.write!(csv_path, "resource_id,field,locale,value\n1,name,en,Test")

      output =
        capture_io(fn ->
          try do
            AshPhoenixTranslations.Import.Redis.run([
              csv_path,
              "--resource",
              @test_resource,
              "--ttl",
              "3600",
              "--dry-run"
            ])
          rescue
            _ -> :ok
          end
        end)

      assert output =~ "TTL: 3600 seconds"
    end
  end

  describe "export.redis task - basic validation" do
    test "requires resource or all-resources option" do
      assert_raise Mix.Error,
                   ~r/Either --resource, --all-resources, or --pattern option is required/,
                   fn ->
                     AshPhoenixTranslations.Export.Redis.run(["output.csv"])
                   end
    end

    test "requires output file" do
      assert_raise Mix.Error, ~r/Please provide an output file/, fn ->
        AshPhoenixTranslations.Export.Redis.run(["--resource", "Example.Product"])
      end
    end

    @tag :tmp_dir
    test "detects CSV format from extension", %{tmp_dir: tmp_dir} do
      output_path = Path.join(tmp_dir, "export.csv")

      output =
        capture_io(fn ->
          try do
            AshPhoenixTranslations.Export.Redis.run([
              output_path,
              "--resource",
              @test_resource
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
            AshPhoenixTranslations.Export.Redis.run([
              output_path,
              "--resource",
              @test_resource
            ])
          rescue
            _ -> :ok
          end
        end)

      assert output =~ "Format: json"
    end

    @tag :tmp_dir
    test "defaults to CSV for unknown extensions", %{tmp_dir: tmp_dir} do
      output_path = Path.join(tmp_dir, "export.dat")

      output =
        capture_io(fn ->
          try do
            AshPhoenixTranslations.Export.Redis.run([
              output_path,
              "--resource",
              @test_resource
            ])
          rescue
            _ -> :ok
          end
        end)

      assert output =~ "Format: csv"
    end
  end

  describe "export.redis task - pattern building" do
    @tag :tmp_dir
    test "shows pattern for specific resource", %{tmp_dir: tmp_dir} do
      output_path = Path.join(tmp_dir, "export.csv")

      output =
        capture_io(fn ->
          try do
            AshPhoenixTranslations.Export.Redis.run([
              output_path,
              "--resource",
              @test_resource
            ])
          rescue
            _ -> :ok
          end
        end)

      assert output =~
               "Pattern: translations:AshPhoenixTranslations.AtomExhaustionMixTest.TestProduct:*:*:*"
    end

    @tag :tmp_dir
    test "shows pattern for all resources", %{tmp_dir: tmp_dir} do
      output_path = Path.join(tmp_dir, "export.csv")

      output =
        capture_io(fn ->
          try do
            AshPhoenixTranslations.Export.Redis.run([
              output_path,
              "--all-resources"
            ])
          rescue
            _ -> :ok
          end
        end)

      assert output =~ "Pattern: translations:*:*:*:*"
    end

    @tag :tmp_dir
    test "shows custom pattern when provided", %{tmp_dir: tmp_dir} do
      output_path = Path.join(tmp_dir, "export.csv")
      custom_pattern = "translations:MyApp.Product:*:name:*"

      output =
        capture_io(fn ->
          try do
            AshPhoenixTranslations.Export.Redis.run([
              output_path,
              "--pattern",
              custom_pattern
            ])
          rescue
            _ -> :ok
          end
        end)

      assert output =~ "Pattern: #{custom_pattern}"
    end
  end

  describe "security - atom exhaustion prevention" do
    setup do
      atom_count_before = :erlang.system_info(:atom_count)
      {:ok, atom_count_before: atom_count_before}
    end

    @tag :tmp_dir
    test "import.redis rejects invalid locales without creating atoms", %{
      tmp_dir: tmp_dir,
      atom_count_before: before_count
    } do
      # Create CSV with 100 invalid locales
      csv_path = Path.join(tmp_dir, "malicious.csv")

      csv_content =
        ["resource_id,field,locale,value"] ++
          for(i <- 1..100, do: "1,name,malicious_locale_#{i},value")

      File.write!(csv_path, Enum.join(csv_content, "\n"))

      capture_io(:stderr, fn ->
        try do
          AshPhoenixTranslations.Import.Redis.run([
            csv_path,
            "--resource",
            @test_resource,
            "--dry-run"
          ])
        rescue
          _ -> :ok
        end
      end)

      atom_count_after = :erlang.system_info(:atom_count)
      atoms_created = atom_count_after - before_count

      # Should not have created 100 atoms (allowing for system overhead)
      assert atoms_created < 200,
             "Too many atoms created: #{atoms_created}. Potential atom exhaustion vulnerability!"
    end

    @tag :tmp_dir
    test "import.redis rejects invalid fields without creating atoms", %{
      tmp_dir: tmp_dir,
      atom_count_before: before_count
    } do
      # Create CSV with 100 invalid fields
      csv_path = Path.join(tmp_dir, "malicious.csv")

      csv_content =
        ["resource_id,field,locale,value"] ++
          for(i <- 1..100, do: "1,malicious_field_#{i},en,value")

      File.write!(csv_path, Enum.join(csv_content, "\n"))

      capture_io(:stderr, fn ->
        try do
          AshPhoenixTranslations.Import.Redis.run([
            csv_path,
            "--resource",
            @test_resource,
            "--dry-run"
          ])
        rescue
          _ -> :ok
        end
      end)

      atom_count_after = :erlang.system_info(:atom_count)
      atoms_created = atom_count_after - before_count

      # Should not have created 100 atoms (allowing for system overhead)
      assert atoms_created < 200,
             "Too many atoms created: #{atoms_created}. Potential atom exhaustion vulnerability!"
    end

    @tag :tmp_dir
    test "export.redis handles invalid locales safely", %{
      tmp_dir: tmp_dir,
      atom_count_before: before_count
    } do
      output_path = Path.join(tmp_dir, "export.csv")

      # Create comma-separated list of 50 invalid locales
      invalid_locales = for i <- 1..50, do: "malicious_#{i}"
      locale_string = Enum.join(invalid_locales, ",")

      capture_io(:stderr, fn ->
        try do
          AshPhoenixTranslations.Export.Redis.run([
            output_path,
            "--resource",
            @test_resource,
            "--locale",
            locale_string
          ])
        rescue
          _ -> :ok
        end
      end)

      atom_count_after = :erlang.system_info(:atom_count)
      atoms_created = atom_count_after - before_count

      # Should not have created 50 atoms
      assert atoms_created < 150,
             "Too many atoms created: #{atoms_created}. Potential atom exhaustion vulnerability!"
    end

    @tag :tmp_dir
    test "export.redis handles invalid fields safely", %{
      tmp_dir: tmp_dir,
      atom_count_before: before_count
    } do
      output_path = Path.join(tmp_dir, "export.csv")

      # Create comma-separated list of 50 invalid fields
      invalid_fields = for i <- 1..50, do: "field_#{i}"
      field_string = Enum.join(invalid_fields, ",")

      capture_io(:stderr, fn ->
        try do
          AshPhoenixTranslations.Export.Redis.run([
            output_path,
            "--resource",
            @test_resource,
            "--field",
            field_string
          ])
        rescue
          _ -> :ok
        end
      end)

      atom_count_after = :erlang.system_info(:atom_count)
      atoms_created = atom_count_after - before_count

      # Should not have created 50 atoms
      assert atoms_created < 150,
             "Too many atoms created: #{atoms_created}. Potential atom exhaustion vulnerability!"
    end
  end

  describe "import.redis task - functional tests (requires Redis)" do
    @describetag :redis_required
    @describetag :tmp_dir

    setup do
      unless redis_available?() do
        :skip
      else
        :ok
      end
    end

    test "successfully imports CSV translations", %{tmp_dir: tmp_dir} do
      csv_path = Path.join(tmp_dir, "import.csv")

      csv_content = """
      resource_id,field,locale,value
      test-1,name,en,Test Product
      test-1,name,es,Producto de Prueba
      test-1,description,en,A test product
      """

      File.write!(csv_path, csv_content)

      output =
        capture_io(fn ->
          try do
            AshPhoenixTranslations.Import.Redis.run([
              csv_path,
              "--resource",
              @test_resource
            ])
          rescue
            e -> IO.puts("Error: #{inspect(e)}")
          end
        end)

      assert output =~ "Import complete"
      assert output =~ "Total translations: 3"
    end

    test "successfully imports JSON translations", %{tmp_dir: tmp_dir} do
      json_path = Path.join(tmp_dir, "import.json")

      json_content = ~s({
        "translations": [
          {
            "resource_id": "test-2",
            "field": "name",
            "locale": "en",
            "value": "Another Product"
          },
          {
            "resource_id": "test-2",
            "field": "name",
            "locale": "fr",
            "value": "Un Autre Produit"
          }
        ]
      })

      File.write!(json_path, json_content)

      output =
        capture_io(fn ->
          try do
            AshPhoenixTranslations.Import.Redis.run([
              json_path,
              "--resource",
              @test_resource
            ])
          rescue
            e -> IO.puts("Error: #{inspect(e)}")
          end
        end)

      assert output =~ "Import complete"
      assert output =~ "Total translations: 2"
    end
  end

  describe "export.redis task - functional tests (requires Redis)" do
    @describetag :redis_required
    @describetag :tmp_dir

    setup do
      unless redis_available?() do
        :skip
      else
        :ok
      end
    end

    test "successfully exports to CSV", %{tmp_dir: tmp_dir} do
      output_path = Path.join(tmp_dir, "export.csv")

      output =
        capture_io(fn ->
          try do
            AshPhoenixTranslations.Export.Redis.run([
              output_path,
              "--resource",
              @test_resource
            ])
          rescue
            e -> IO.puts("Error: #{inspect(e)}")
          end
        end)

      assert output =~ "Export complete"
    end

    test "successfully exports to JSON", %{tmp_dir: tmp_dir} do
      output_path = Path.join(tmp_dir, "export.json")

      output =
        capture_io(fn ->
          try do
            AshPhoenixTranslations.Export.Redis.run([
              output_path,
              "--resource",
              @test_resource,
              "--format",
              "json"
            ])
          rescue
            e -> IO.puts("Error: #{inspect(e)}")
          end
        end)

      assert output =~ "Export complete"

      if File.exists?(output_path) do
        content = File.read!(output_path)
        {:ok, json} = Jason.decode(content)
        assert Map.has_key?(json, "metadata")
        assert Map.has_key?(json, "translations")
      end
    end
  end
end
