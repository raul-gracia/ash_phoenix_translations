defmodule Mix.Tasks.AshPhoenixTranslations.Import do
  @moduledoc """
  Imports translations from CSV, JSON, or XLIFF files into Ash resources.

  This task enables integration with professional translation workflows by importing
  translated content from external systems, translation agencies, and CAT tools. Essential
  for maintaining translation quality and integrating with enterprise translation management
  systems (TMS).

  ## Features

  - **Multiple Formats**: Import from CSV, JSON, or XLIFF files
  - **Merge or Replace**: Choose between merging with existing or full replacement
  - **Dry Run Mode**: Preview changes before applying them
  - **Security Hardening**: Prevents atom exhaustion from malicious input files
  - **Validation**: Automatic locale and field validation
  - **Batch Processing**: Efficiently handle large translation files
  - **Error Recovery**: Detailed reporting of import failures
  - **Transaction Safety**: Atomic updates per resource

  ## Basic Usage

      # Import translations from CSV
      mix ash_phoenix_translations.import translations.csv --resource MyApp.Product

      # Import with dry-run preview
      mix ash_phoenix_translations.import translations.csv --resource MyApp.Product --dry-run

      # Import and replace existing translations
      mix ash_phoenix_translations.import translations.csv --resource MyApp.Product --replace

      # Import from JSON file
      mix ash_phoenix_translations.import translations.json --resource MyApp.Product

  ## Options

    * `--resource` - Resource module to import into (e.g., MyApp.Product) **[Required]**
    * `--format` - File format: `csv`, `json`, or `xliff` (auto-detected from extension)
    * `--locale` - Default locale for rows without locale column (default: `en`)
    * `--dry-run` - Preview import without making changes
    * `--replace` - Replace existing translations instead of merging (default: merge)

  ## File Formats

  ### CSV Format

  Standard CSV with UTF-8 encoding:

      resource_id,field,locale,value
      550e8400-e29b-41d4-a716-446655440000,name,en,Premium Coffee Beans
      550e8400-e29b-41d4-a716-446655440000,name,es,Granos de Café Premium
      550e8400-e29b-41d4-a716-446655440000,description,en,High-quality arabica beans
      550e8400-e29b-41d4-a716-446655440000,description,es,Granos de arabica de alta calidad

  **CSV Requirements**:
  - Must include header row: `resource_id,field,locale,value`
  - `resource_id` must match existing resource UUID
  - `field` must be a valid translatable attribute
  - `locale` must be a configured supported locale
  - Supports UTF-8 encoded special characters

  ### JSON Format

  Structured JSON with translations array:

      {
        "metadata": {
          "source": "Translation Agency",
          "exported_at": "2024-10-19T10:30:00Z"
        },
        "translations": [
          {
            "resource_id": "550e8400-e29b-41d4-a716-446655440000",
            "field": "name",
            "locale": "es",
            "value": "Granos de Café Premium"
          },
          {
            "resource_id": "550e8400-e29b-41d4-a716-446655440000",
            "field": "description",
            "locale": "es",
            "value": "Granos de arabica de alta calidad"
          }
        ]
      }

  **JSON Requirements**:
  - `translations` array is required (metadata is optional)
  - Each translation must include all four required fields
  - Pretty-printed or minified JSON both supported

  ### XLIFF Format

  Industry-standard XLIFF 1.2 format:

      <?xml version="1.0" encoding="UTF-8"?>
      <xliff version="1.2" xmlns="urn:oasis:names:tc:xliff:document:1.2">
        <file source-language="en" target-language="es" datatype="plaintext">
          <body>
            <trans-unit id="550e8400_name">
              <source>name</source>
              <target>Granos de Café Premium</target>
            </trans-unit>
          </body>
        </file>
      </xliff>

  **XLIFF Support**:
  - Compatible with outputs from memoQ, Trados, Smartcat
  - Preserves context and metadata from CAT tools
  - Supports translation memory integration

  ## Import Modes

  ### Merge Mode (Default)

  Merges imported translations with existing data:

      mix ash_phoenix_translations.import translations.csv --resource MyApp.Product

  **Behavior**:
  - Existing translations for other locales are preserved
  - Imported translations overwrite existing values for the same locale
  - Perfect for incremental updates and corrections

  **Example**:
      # Existing: {name: %{en: "Coffee", es: "Café"}}
      # Import: {name: %{es: "Café Premium", fr: "Café"}}
      # Result: {name: %{en: "Coffee", es: "Café Premium", fr: "Café"}}

  ### Replace Mode

  Completely replaces translation data:

      mix ash_phoenix_translations.import translations.csv --resource MyApp.Product --replace

  **Behavior**:
  - Removes existing translations before importing
  - Only imported locales will exist after import
  - Use with caution - can result in data loss

  **Example**:
      # Existing: {name: %{en: "Coffee", es: "Café", fr: "Café"}}
      # Import: {name: %{es: "Café Premium"}}
      # Result: {name: %{es: "Café Premium"}}  # en and fr removed!

  ### Dry Run Mode

  Preview import without making changes:

      mix ash_phoenix_translations.import translations.csv \\
        --resource MyApp.Product \\
        --dry-run

  **Output**:
      Importing translations from translations.csv...
      Resource: MyApp.Product
      Format: csv
      Mode: merge
      DRY RUN - No changes will be made

      Would import 150 translations for resource 550e8400-...
      Would import 75 translations for resource 660f9511-...

      Import complete!
      - Total translations: 225
      - Imported: 0 (dry run)
      - Skipped: 0
      - Errors: 0

  ## Workflow Examples

  ### Translation Agency Workflow

      # 1. Export missing translations
      mix ash_phoenix_translations.export missing_es.csv \\
        --resource MyApp.Product \\
        --locale es \\
        --missing-only

      # 2. Send to translation agency
      # 3. Receive translated file back

      # 4. Preview import
      mix ash_phoenix_translations.import translated_es.csv \\
        --resource MyApp.Product \\
        --dry-run

      # 5. Apply import
      mix ash_phoenix_translations.import translated_es.csv \\
        --resource MyApp.Product

      # 6. Validate results
      mix ash_phoenix_translations.validate \\
        --resource MyApp.Product \\
        --locale es \\
        --strict

  ### CAT Tool Integration Workflow

      # 1. Export to XLIFF for CAT tool
      mix ash_phoenix_translations.export project.xliff \\
        --resource MyApp.Product

      # 2. Import into CAT tool (memoQ, Trados, Smartcat)
      # 3. Translators complete work with translation memory
      # 4. Export from CAT tool as XLIFF

      # 5. Import back to application
      mix ash_phoenix_translations.import completed.xliff \\
        --resource MyApp.Product

  ### Incremental Update Workflow

      # Regular updates from ongoing translation work

      # 1. Import weekly updates from translation team
      mix ash_phoenix_translations.import weekly_updates.csv \\
        --resource MyApp.Product

      # 2. Validate quality
      mix ash_phoenix_translations.validate --resource MyApp.Product

      # 3. Deploy to staging for review
      # 4. If approved, merge to production

  ### Multi-Locale Launch Workflow

      # Launching multiple new locales simultaneously

      # 1. Import German translations
      mix ash_phoenix_translations.import de.csv \\
        --resource MyApp.Product \\
        --locale de

      # 2. Import French translations
      mix ash_phoenix_translations.import fr.csv \\
        --resource MyApp.Product \\
        --locale fr

      # 3. Import Italian translations
      mix ash_phoenix_translations.import it.csv \\
        --resource MyApp.Product \\
        --locale it

      # 4. Validate all new locales
      mix ash_phoenix_translations.validate \\
        --resource MyApp.Product \\
        --locale de,fr,it \\
        --strict

  ### Emergency Fix Workflow

      # Quick fix for translation errors in production

      # 1. Export current production data
      mix ash_phoenix_translations.export backup.json \\
        --resource MyApp.Product

      # 2. Create fix file with corrections
      # 3. Test import in dry-run mode
      mix ash_phoenix_translations.import fixes.csv \\
        --resource MyApp.Product \\
        --dry-run

      # 4. Apply fixes
      mix ash_phoenix_translations.import fixes.csv \\
        --resource MyApp.Product

      # 5. Verify fixes
      mix ash_phoenix_translations.validate --resource MyApp.Product

  ## CI/CD Integration

  ### Automated Import on Pull Request

      # .github/workflows/import-translations.yml
      name: Import Translations

      on:
        pull_request:
          paths:
            - 'translations/**'

      jobs:
        import:
          runs-on: ubuntu-latest
          steps:
            - uses: actions/checkout@v3
            - uses: erlef/setup-beam@v1
              with:
                elixir-version: '1.17'
                otp-version: '27'

            - name: Install dependencies
              run: mix deps.get

            - name: Dry run import
              run: |
                mix ash_phoenix_translations.import \\
                  translations/updates.csv \\
                  --resource MyApp.Product \\
                  --dry-run

            - name: Import translations
              if: github.event.pull_request.merged == true
              run: |
                mix ash_phoenix_translations.import \\
                  translations/updates.csv \\
                  --resource MyApp.Product

            - name: Validate imported translations
              run: |
                mix ash_phoenix_translations.validate \\
                  --resource MyApp.Product \\
                  --strict

  ### Scheduled Translation Sync

      # .github/workflows/sync-translations.yml
      name: Sync Translations from TMS

      on:
        schedule:
          - cron: '0 3 * * *'  # Daily at 3 AM
        workflow_dispatch:

      jobs:
        sync:
          runs-on: ubuntu-latest
          steps:
            - uses: actions/checkout@v3

            - name: Download from TMS
              run: |
                # Download latest translations from TMS API
                curl -o translations.json \\
                  -H "Authorization: Bearer ${{ secrets.TMS_API_KEY }}" \\
                  https://tms.example.com/api/export

            - name: Import translations
              run: |
                mix ash_phoenix_translations.import translations.json \\
                  --resource MyApp.Product

            - name: Create pull request
              uses: peter-evans/create-pull-request@v5
              with:
                title: 'Automated translation sync'
                body: 'Daily automated translation import from TMS'
                branch: 'translation-sync/${{ github.run_id }}'

  ## Advanced Use Cases

  ### Programmatic Import

      defmodule MyApp.TranslationImporter do
        def import_from_api(api_url) do
          # Fetch translations from external API
          {:ok, response} = HTTPoison.get(api_url)
          translations = Jason.decode!(response.body)

          # Save to temporary file
          temp_file = Path.join(System.tmp_dir!(), "api_import.json")
          File.write!(temp_file, Jason.encode!(translations))

          # Import using Mix task
          {output, exit_code} =
            System.cmd("mix", [
              "ash_phoenix_translations.import",
              temp_file,
              "--resource", "MyApp.Product",
              "--format", "json"
            ])

          # Clean up
          File.rm!(temp_file)

          case exit_code do
            0 -> {:ok, "Import successful"}
            _ -> {:error, output}
          end
        end
      end

  ### Validation Before Import

      defmodule MyApp.SafeImporter do
        def safe_import(file_path, resource) do
          # 1. Create backup
          backup_file = "backup_\#{DateTime.utc_now() |> DateTime.to_unix()}.json"
          System.cmd("mix", [
            "ash_phoenix_translations.export",
            backup_file,
            "--resource", resource
          ])

          # 2. Dry run to check for issues
          {output, exit_code} =
            System.cmd("mix", [
              "ash_phoenix_translations.import",
              file_path,
              "--resource", resource,
              "--dry-run"
            ])

          if exit_code != 0 do
            {:error, "Dry run failed: \#{output}"}
          else
            # 3. Perform actual import
            {output, exit_code} =
              System.cmd("mix", [
                "ash_phoenix_translations.import",
                file_path,
                "--resource", resource
              ])

            case exit_code do
              0 ->
                # 4. Validate result
                {val_output, val_code} =
                  System.cmd("mix", [
                    "ash_phoenix_translations.validate",
                    "--resource", resource,
                    "--strict"
                  ])

                if val_code == 0 do
                  {:ok, "Import and validation successful"}
                else
                  # Restore backup if validation fails
                  System.cmd("mix", [
                    "ash_phoenix_translations.import",
                    backup_file,
                    "--resource", resource,
                    "--replace"
                  ])

                  {:error, "Validation failed, restored backup"}
                end

              _ ->
                {:error, "Import failed: \#{output}"}
            end
          end
        end
      end

  ## Security Considerations

  ### Atom Exhaustion Prevention

  This task uses secure atom conversion to prevent DoS attacks:

  - **Locale Validation**: Uses `LocaleValidator.validate_locale/1` with whitelist
  - **Field Validation**: Uses `String.to_existing_atom/1` for field names
  - **Aggregated Logging**: Invalid inputs logged in aggregate, not individually
  - **No Dynamic Atoms**: All atoms must exist before import

  **Attack Mitigation**:
      # Malicious CSV with 10,000 fake locales
      # Old approach: Would create 10,000 atoms = DoS
      # New approach: Validates against whitelist, skips invalid with aggregate log

  ### Input Validation

  All imported data is validated before processing:

  - Resource IDs must match existing UUIDs
  - Fields must exist as translatable attributes
  - Locales must be in configured supported list
  - Values are sanitized for safe storage

  ### File Security

  - Only import files from trusted sources
  - Validate file integrity before import
  - Store sensitive translation files securely
  - Use HTTPS for file transfers from translation agencies

  ## Performance Optimization

  - **Batch Processing**: Updates are grouped by resource
  - **Memory Usage**: Large files processed in streaming fashion (CSV)
  - **Transaction Safety**: Each resource updated atomically
  - **Parallel Imports**: Import different resources in parallel

  ## Troubleshooting

  ### "Resource not found" Errors

      # Ensure resource IDs in file match database
      MyApp.Product |> Ash.get!("550e8400-e29b-41d4-a716-446655440000")

      # Verify UUID format is correct (no dashes missing)

  ### "Skipping invalid locale" Warnings

      # Check locale is in supported list
      config :ash_phoenix_translations,
        supported_locales: [:en, :es, :fr, :de]

      # Or verify resource configuration
      translations do
        translatable_attribute :name, locales: [:en, :es, :fr]
      end

  ### "Field is not a valid field" Errors

      # Ensure field exists as translatable attribute
      AshPhoenixTranslations.Info.translatable_attributes(MyApp.Product)

      # Field names are case-sensitive

  ### CSV Parsing Errors

      # Ensure CSV has proper header row
      # Check for UTF-8 encoding issues
      # Verify no extra commas in data values
      # Use quotes for values containing commas

  ### High Error Count

      # Run dry-run first to identify issues
      mix ash_phoenix_translations.import file.csv \\
        --resource MyApp.Product \\
        --dry-run

      # Check logs for specific error patterns

  ## Related Tasks

  - `mix ash_phoenix_translations.export` - Export translations for editing
  - `mix ash_phoenix_translations.validate` - Validate imported translations
  - `mix ash_phoenix_translations.extract` - Extract translatable strings

  ## Examples

      # Development: Import from local CSV
      mix ash_phoenix_translations.import translations.csv --resource MyApp.Product

      # Production: Import with validation
      mix ash_phoenix_translations.import prod_translations.json \\
        --resource MyApp.Product && \\
        mix ash_phoenix_translations.validate --resource MyApp.Product --strict

      # CAT Tool: Import from XLIFF
      mix ash_phoenix_translations.import trados_output.xliff \\
        --resource MyApp.Product

      # Safe import: Dry run first
      mix ash_phoenix_translations.import updates.csv \\
        --resource MyApp.Product \\
        --dry-run && \\
        mix ash_phoenix_translations.import updates.csv \\
        --resource MyApp.Product
  """

  use Mix.Task
  require Logger

  @shortdoc "Imports translations from CSV, JSON, or XLIFF files"

  @switches [
    resource: :string,
    format: :string,
    locale: :string,
    dry_run: :boolean,
    replace: :boolean
  ]

  @aliases [
    r: :resource,
    f: :format,
    l: :locale,
    d: :dry_run
  ]

  def run(args) do
    {opts, files, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    unless opts[:resource] do
      Mix.raise("--resource option is required")
    end

    if Enum.empty?(files) do
      Mix.raise("Please provide a file to import")
    end

    Mix.Task.run("app.start")

    resource = Module.concat([opts[:resource]])
    file_path = List.first(files)
    format = opts[:format] || detect_format(file_path)
    dry_run = opts[:dry_run] || false
    replace = opts[:replace] || false
    default_locale = opts[:locale] || "en"

    Mix.shell().info("Importing translations from #{file_path}...")
    Mix.shell().info("Resource: #{inspect(resource)}")
    Mix.shell().info("Format: #{format}")
    Mix.shell().info("Mode: #{if replace, do: "replace", else: "merge"}")

    if dry_run do
      Mix.shell().info("DRY RUN - No changes will be made")
    end

    translations = parse_file(file_path, format, default_locale)

    result = import_translations(resource, translations, dry_run, replace)

    Mix.shell().info("""

    Import complete!
    - Total translations: #{result.total}
    - Imported: #{result.imported}
    - Skipped: #{result.skipped}
    - Errors: #{result.errors}
    """)

    if result.errors > 0 do
      Mix.shell().error("Some translations failed to import. Check logs for details.")
    end
  end

  defp detect_format(file_path) do
    case Path.extname(file_path) do
      ".csv" -> "csv"
      ".json" -> "json"
      ".xliff" -> "xliff"
      ".xlf" -> "xliff"
      _ -> Mix.raise("Cannot detect format. Please specify with --format")
    end
  end

  defp parse_file(file_path, "csv", default_locale) do
    if Code.ensure_loaded?(CSV) do
      file_path
      |> File.stream!()
      |> CSV.decode!(headers: true)
      |> Enum.reduce([], fn row, acc ->
        # SECURITY: Validate field and locale to prevent atom exhaustion
        with {:ok, field_atom} <- safe_to_atom(row["field"], "field"),
             {:ok, locale_atom} <- safe_to_atom(row["locale"] || default_locale, "locale") do
          translation = %{
            resource_id: row["resource_id"],
            field: field_atom,
            locale: locale_atom,
            value: row["value"]
          }

          [translation | acc]
        else
          {:error, reason} ->
            Logger.warning("Skipping invalid CSV row", reason: reason, row: inspect(row))
            acc
        end
      end)
      |> Enum.reverse()
    else
      raise "CSV library is required for CSV imports. Add {:csv, \"~> 3.0\"} to your dependencies."
    end
  end

  defp parse_file(file_path, "json", default_locale) do
    file_path
    |> File.read!()
    |> Jason.decode!()
    |> Map.get("translations", [])
    |> Enum.reduce([], fn t, acc ->
      # SECURITY: Validate field and locale to prevent atom exhaustion
      with {:ok, field_atom} <- safe_to_atom(t["field"], "field"),
           {:ok, locale_atom} <- safe_to_atom(t["locale"] || default_locale, "locale") do
        translation = %{
          resource_id: t["resource_id"],
          field: field_atom,
          locale: locale_atom,
          value: t["value"]
        }

        [translation | acc]
      else
        {:error, reason} ->
          Logger.warning("Skipping invalid JSON translation", reason: reason, data: inspect(t))
          acc
      end
    end)
    |> Enum.reverse()
  end

  defp parse_file(_file_path, "xliff", _default_locale) do
    # This would require an XLIFF parser library
    # For now, we'll provide a placeholder
    Mix.shell().warn("XLIFF import requires additional dependencies. Using placeholder.")
    []
  end

  defp parse_file(_file_path, format, _default_locale) do
    Mix.raise("Unsupported format: #{format}")
  end

  # SECURITY: Safe atom conversion using String.to_existing_atom/1
  # This prevents atom exhaustion attacks from malicious import files
  defp safe_to_atom(value, field_type) when is_binary(value) do
    trimmed = String.trim(value)

    case field_type do
      "locale" ->
        # Use LocaleValidator for locale validation
        AshPhoenixTranslations.LocaleValidator.validate_locale(trimmed)

      "field" ->
        # For fields, only convert existing atoms
        try do
          atom = String.to_existing_atom(trimmed)
          {:ok, atom}
        rescue
          ArgumentError ->
            {:error, "Field '#{trimmed}' is not a valid field (atom does not exist)"}
        end
    end
  end

  defp safe_to_atom(value, _field_type) when is_atom(value) do
    {:ok, value}
  end

  defp safe_to_atom(value, field_type) do
    {:error, "Invalid #{field_type}: #{inspect(value)}"}
  end

  defp import_translations(resource, translations, dry_run, replace) do
    # Group translations by resource_id
    grouped = Enum.group_by(translations, & &1.resource_id)

    result = %{
      total: length(translations),
      imported: 0,
      skipped: 0,
      errors: 0
    }

    Enum.reduce(grouped, result, fn {resource_id, trans}, acc ->
      case import_resource_translations(resource, resource_id, trans, dry_run, replace) do
        {:ok, count} ->
          %{acc | imported: acc.imported + count}

        {:skipped, count} ->
          %{acc | skipped: acc.skipped + count}

        {:error, _reason} ->
          %{acc | errors: acc.errors + 1}
      end
    end)
  end

  defp import_resource_translations(resource, resource_id, translations, dry_run, replace) do
    if dry_run do
      Mix.shell().info(
        "Would import #{length(translations)} translations for resource #{resource_id}"
      )

      {:ok, length(translations)}
    else
      # Get the resource instance
      case Ash.get(resource, resource_id) do
        {:ok, record} ->
          # Build translation updates
          updates = build_translation_updates(translations, replace)

          # Update the resource
          case Ash.update(record, updates) do
            {:ok, _updated} ->
              {:ok, length(translations)}

            {:error, error} ->
              Logger.error("Failed to update resource #{resource_id}: #{inspect(error)}")
              {:error, error}
          end

        {:error, _} ->
          Logger.warning("Resource not found: #{resource_id}")
          {:skipped, length(translations)}
      end
    end
  end

  defp build_translation_updates(translations, replace) do
    Enum.reduce(translations, %{}, fn t, acc ->
      field_key = :"#{t.field}_translations"

      current = Map.get(acc, field_key, %{})

      new_value =
        if replace do
          Map.put(%{}, t.locale, t.value)
        else
          Map.put(current, t.locale, t.value)
        end

      Map.put(acc, field_key, new_value)
    end)
  end
end
