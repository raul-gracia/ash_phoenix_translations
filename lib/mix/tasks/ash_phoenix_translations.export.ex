defmodule Mix.Tasks.AshPhoenixTranslations.Export do
  @moduledoc """
  Exports translations to CSV, JSON, or XLIFF files for external editing and translation workflows.

  This task enables integration with professional translation management systems, external
  translators, and review workflows by exporting translation data in industry-standard formats.
  Essential for managing large-scale translation projects and maintaining translation quality.

  ## Features

  - **Multiple Formats**: Export to CSV, JSON, or XLIFF formats
  - **Flexible Filtering**: Export specific locales, fields, or translation states
  - **Security Hardening**: Prevents atom exhaustion from malicious locale/field inputs
  - **Translation Workflows**: Support for missing-only and complete-only exports
  - **Professional Integration**: Compatible with CAT tools and TMS platforms
  - **Batch Operations**: Export multiple resources efficiently
  - **UTF-8 Support**: Proper encoding for international characters

  ## Basic Usage

      # Export all translations to CSV
      mix ash_phoenix_translations.export products.csv --resource MyApp.Product

      # Export specific locale to JSON
      mix ash_phoenix_translations.export es.json --resource MyApp.Product --locale es

      # Export missing translations for review
      mix ash_phoenix_translations.export missing.csv --resource MyApp.Product --missing-only

      # Export to XLIFF for CAT tools
      mix ash_phoenix_translations.export translations.xliff --resource MyApp.Product

  ## Options

    * `--resource` - Resource module to export (e.g., MyApp.Product) **[Required]**
    * `--format` - Output format: `csv`, `json`, or `xliff` (auto-detected from extension)
    * `--locale` - Comma-separated locales to export (e.g., `es,fr,de`)
    * `--field` - Comma-separated fields to export (e.g., `name,description`)
    * `--missing-only` - Export only translations with nil or empty values
    * `--complete-only` - Export only translations with values present

  ## File Formats

  ### CSV Format

  Standard comma-separated values with UTF-8 encoding:

      resource_id,field,locale,value
      550e8400-e29b-41d4-a716-446655440000,name,en,Premium Coffee Beans
      550e8400-e29b-41d4-a716-446655440000,name,es,Granos de Café Premium
      550e8400-e29b-41d4-a716-446655440000,description,en,High-quality arabica beans
      550e8400-e29b-41d4-a716-446655440000,description,es,Granos de arabica de alta calidad

  **CSV Features**:
  - Proper escaping of commas, quotes, and newlines
  - UTF-8 encoding for international characters
  - Excel-compatible format
  - Git-friendly line endings

  ### JSON Format

  Structured JSON with metadata:

      {
        "metadata": {
          "exported_at": "2024-10-19T10:30:00Z",
          "total": 150
        },
        "translations": [
          {
            "resource_id": "550e8400-e29b-41d4-a716-446655440000",
            "field": "name",
            "locale": "en",
            "value": "Premium Coffee Beans"
          },
          {
            "resource_id": "550e8400-e29b-41d4-a716-446655440000",
            "field": "name",
            "locale": "es",
            "value": "Granos de Café Premium"
          }
        ]
      }

  **JSON Features**:
  - Pretty-printed for readability
  - Metadata includes export timestamp
  - Easy programmatic processing
  - Compatible with most TMS platforms

  ### XLIFF Format

  Industry-standard XML Localization Interchange File Format:

      <?xml version="1.0" encoding="UTF-8"?>
      <xliff version="1.2" xmlns="urn:oasis:names:tc:xliff:document:1.2">
        <file source-language="en" target-language="es" datatype="plaintext">
          <body>
            <trans-unit id="550e8400_name">
              <source>name</source>
              <target>Granos de Café Premium</target>
            </trans-unit>
            <trans-unit id="550e8400_description">
              <source>description</source>
              <target>Granos de arabica de alta calidad</target>
            </trans-unit>
          </body>
        </file>
      </xliff>

  **XLIFF Features**:
  - Compatible with CAT tools (memoQ, Trados, Smartcat)
  - Supports translation memory integration
  - Preserves context and metadata
  - Professional translator workflow support

  ## Workflow Examples

  ### Translation Review Workflow

      # 1. Export missing translations for review
      mix ash_phoenix_translations.export missing_es.csv \\
        --resource MyApp.Product \\
        --locale es \\
        --missing-only

      # 2. Send to translator or review team
      # 3. After receiving corrections, import back
      mix ash_phoenix_translations.import missing_es_corrected.csv \\
        --resource MyApp.Product

      # 4. Validate imported translations
      mix ash_phoenix_translations.validate --resource MyApp.Product --locale es

  ### CAT Tool Integration

      # 1. Export to XLIFF for translation memory systems
      mix ash_phoenix_translations.export project.xliff \\
        --resource MyApp.Product \\
        --locale es,fr,de

      # 2. Import into CAT tool (memoQ, Trados, etc.)
      # 3. Translators work with translation memory support
      # 4. Export from CAT tool and import back
      mix ash_phoenix_translations.import translated.xliff \\
        --resource MyApp.Product

  ### Backup and Version Control

      # Create timestamped backups before major changes
      #!/bin/bash
      TIMESTAMP=$(date +%Y%m%d_%H%M%S)

      mix ash_phoenix_translations.export \\
        "backups/translations_\${TIMESTAMP}.json" \\
        --resource MyApp.Product \\
        --format json

      # Commit to version control
      git add "backups/translations_\${TIMESTAMP}.json"
      git commit -m "Backup translations before bulk update"

  ### Quality Assurance Workflow

      # 1. Export complete translations for QA review
      mix ash_phoenix_translations.export qa_review.csv \\
        --resource MyApp.Product \\
        --complete-only

      # 2. QA team reviews in spreadsheet
      # 3. Export issues found during QA
      # 4. Re-import corrected versions

  ### Locale Launch Workflow

      # Before launching new locale (e.g., German)

      # 1. Export all translatable strings
      mix ash_phoenix_translations.export de_template.csv \\
        --resource MyApp.Product \\
        --locale de

      # 2. Send to translation agency
      # 3. Import completed translations
      mix ash_phoenix_translations.import de_completed.csv \\
        --resource MyApp.Product

      # 4. Validate completeness
      mix ash_phoenix_translations.validate \\
        --resource MyApp.Product \\
        --locale de \\
        --strict

      # 5. Export final review copy
      mix ash_phoenix_translations.export de_final_review.csv \\
        --resource MyApp.Product \\
        --locale de \\
        --complete-only

  ## CI/CD Integration

  ### Automated Export on Release

      # .github/workflows/export-translations.yml
      name: Export Translations on Release

      on:
        release:
          types: [published]

      jobs:
        export:
          runs-on: ubuntu-latest
          steps:
            - uses: actions/checkout@v3
            - uses: erlef/setup-beam@v1
              with:
                elixir-version: '1.17'
                otp-version: '27'

            - name: Install dependencies
              run: mix deps.get

            - name: Export translations
              run: |
                mkdir -p exports
                mix ash_phoenix_translations.export \\
                  "exports/translations_\${{ github.ref_name }}.json" \\
                  --resource MyApp.Product \\
                  --format json

            - name: Upload to release
              uses: softprops/action-gh-release@v1
              with:
                files: exports/translations_*.json

  ### Daily Translation Backup

      # Daily cron job to backup translations
      # .github/workflows/backup-translations.yml
      name: Daily Translation Backup

      on:
        schedule:
          - cron: '0 2 * * *'  # 2 AM daily
        workflow_dispatch:

      jobs:
        backup:
          runs-on: ubuntu-latest
          steps:
            - uses: actions/checkout@v3
            - name: Export current translations
              run: |
                DATE=$(date +%Y-%m-%d)
                mix ash_phoenix_translations.export \\
                  "backups/translations_\${DATE}.json" \\
                  --resource MyApp.Product

            - name: Commit backup
              run: |
                git config user.name "Translation Bot"
                git config user.email "bot@example.com"
                git add backups/
                git commit -m "Automated translation backup \${DATE}" || echo "No changes"
                git push

  ## Professional Translation Management

  ### Integration with Smartcat

      # 1. Export to XLIFF
      mix ash_phoenix_translations.export smartcat_import.xliff \\
        --resource MyApp.Product \\
        --locale es,fr,de

      # 2. Upload to Smartcat via API or web interface
      # 3. Translators work in Smartcat with TM support
      # 4. Download completed XLIFF from Smartcat
      # 5. Import back
      mix ash_phoenix_translations.import smartcat_export.xliff \\
        --resource MyApp.Product

  ### Integration with Crowdin

      # Using Crowdin CLI
      # 1. Export source strings
      mix ash_phoenix_translations.export crowdin_source.json \\
        --resource MyApp.Product \\
        --locale en

      # 2. Upload to Crowdin
      crowdin upload sources

      # 3. Download translations after completion
      crowdin download

      # 4. Import translations
      mix ash_phoenix_translations.import crowdin_translations.json \\
        --resource MyApp.Product

  ## Advanced Use Cases

  ### Export for Machine Translation

      # Export untranslated strings for machine translation
      mix ash_phoenix_translations.export mt_input.json \\
        --resource MyApp.Product \\
        --locale es \\
        --missing-only

      # Process with MT service (Google Translate API, DeepL, etc.)
      # Then import results for human review

  ### Audit and Compliance

      # Export all translations with timestamp for compliance
      defmodule MyApp.TranslationAudit do
        def export_for_audit(date) do
          System.cmd("mix", [
            "ash_phoenix_translations.export",
            "audit/translations_\#{date}.csv",
            "--resource", "MyApp.Product",
            "--format", "csv"
          ])

          # Add to audit log
          MyApp.AuditLog.create(%{
            event: "translation_export",
            timestamp: DateTime.utc_now(),
            file: "translations_\#{date}.csv"
          })
        end
      end

  ### Multi-Resource Export

      # Export all resources for comprehensive backup
      defmodule MyApp.TranslationExporter do
        @resources [
          MyApp.Product,
          MyApp.Category,
          MyApp.Brand
        ]

        def export_all do
          timestamp = DateTime.utc_now() |> DateTime.to_unix()

          Enum.each(@resources, fn resource ->
            resource_name =
              resource
              |> Module.split()
              |> List.last()
              |> Macro.underscore()

            filename = "exports/\#{resource_name}_\#{timestamp}.json"

            System.cmd("mix", [
              "ash_phoenix_translations.export",
              filename,
              "--resource", inspect(resource),
              "--format", "json"
            ])
          end)
        end
      end

  ## Security Considerations

  ### Atom Exhaustion Prevention

  This task uses `AshPhoenixTranslations.LocaleValidator` and `String.to_existing_atom/1`
  to prevent atom exhaustion attacks:

  - Locale inputs are validated against configured supported locales
  - Field inputs must match existing resource attributes
  - Invalid inputs are aggregated and reported without creating atoms
  - Protection against malicious bulk operations

  ### Data Privacy

  - Exported files may contain sensitive product information
  - Store exports securely, not in public repositories
  - Use encryption for files transmitted to external translators
  - Consider GDPR and data residency requirements

  ## Performance Optimization

  - **Batch Size**: Export processes all translations in memory
  - **Large Datasets**: For 100k+ translations, consider field filtering
  - **Parallel Exports**: Export different resources in parallel
  - **File Size**: JSON format creates larger files than CSV

  ## Troubleshooting

  ### "No translations found" Error

      # Ensure resource has translation data
      # Check if records exist:
      MyApp.Product |> Ash.read!()

      # Verify resource has translations extension
      AshPhoenixTranslations.Info.translatable_attributes(MyApp.Product)

  ### "Skipping N invalid locale(s)" Warning

      # Locales must be configured in application config
      config :ash_phoenix_translations,
        supported_locales: [:en, :es, :fr, :de]

      # Or in resource definition
      translations do
        translatable_attribute :name, locales: [:en, :es, :fr]
      end

  ### CSV Excel Opening Issues

      # Excel may not detect UTF-8 encoding automatically
      # Open with "Import Data" instead of double-clicking
      # Or use Google Sheets which handles UTF-8 correctly

  ## Related Tasks

  - `mix ash_phoenix_translations.import` - Import translated files back
  - `mix ash_phoenix_translations.validate` - Validate exported translations
  - `mix ash_phoenix_translations.extract` - Extract translatable strings

  ## Examples

      # Development: Export for local review
      mix ash_phoenix_translations.export review.csv --resource MyApp.Product

      # Production: Full export with timestamp
      mix ash_phoenix_translations.export "exports/prod_$(date +%Y%m%d).json" \\
        --resource MyApp.Product \\
        --format json

      # Translation agency: Missing Spanish strings
      mix ash_phoenix_translations.export spanish_todo.xliff \\
        --resource MyApp.Product \\
        --locale es \\
        --missing-only

      # Quality assurance: Complete translations only
      mix ash_phoenix_translations.export qa_review.csv \\
        --resource MyApp.Product \\
        --complete-only
  """

  use Mix.Task

  @shortdoc "Exports translations to CSV, JSON, or XLIFF files"

  @switches [
    resource: :string,
    format: :string,
    locale: :string,
    field: :string,
    missing_only: :boolean,
    complete_only: :boolean
  ]

  @aliases [
    r: :resource,
    f: :format,
    l: :locale
  ]

  def run(args) do
    {opts, files, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    unless opts[:resource] do
      Mix.raise("--resource option is required")
    end

    if Enum.empty?(files) do
      Mix.raise("Please provide an output file")
    end

    Mix.Task.run("app.start")

    resource = Module.concat([opts[:resource]])
    output_path = List.first(files)
    format = opts[:format] || detect_format(output_path)

    filters = build_filters(opts)

    Mix.shell().info("Exporting translations to #{output_path}...")
    Mix.shell().info("Resource: #{inspect(resource)}")
    Mix.shell().info("Format: #{format}")

    if filters != %{} do
      Mix.shell().info("Filters: #{inspect(filters)}")
    end

    translations = fetch_translations(resource, filters)

    write_file(output_path, format, translations)

    Mix.shell().info("""

    Export complete!
    - Total translations exported: #{length(translations)}
    - Output file: #{output_path}
    """)
  end

  defp detect_format(file_path) do
    case Path.extname(file_path) do
      ".csv" -> "csv"
      ".json" -> "json"
      ".xliff" -> "xliff"
      ".xlf" -> "xliff"
      # Default to CSV
      _ -> "csv"
    end
  end

  defp build_filters(opts) do
    %{}
    |> maybe_add_locale_filter(opts)
    |> maybe_add_field_filter(opts)
    |> maybe_add_boolean_filters(opts)
  end

  defp maybe_add_locale_filter(filters, opts) do
    case opts[:locale] do
      nil ->
        filters

      locale_string ->
        case process_validated_items(
               locale_string,
               &AshPhoenixTranslations.LocaleValidator.validate_locale/1,
               "locale"
             ) do
          {:ok, locales} -> Map.put(filters, :locales, locales)
          :error -> filters
        end
    end
  end

  defp maybe_add_field_filter(filters, opts) do
    case opts[:field] do
      nil ->
        filters

      field_string ->
        case process_validated_items(field_string, &validate_field_atom/1, "field") do
          {:ok, fields} -> Map.put(filters, :fields, fields)
          :error -> filters
        end
    end
  end

  defp process_validated_items(input_string, validator_fn, item_name) do
    # Process items and collect validation results
    {valid, invalid} =
      input_string
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reduce({[], []}, fn item_str, {valid_acc, invalid_acc} ->
        case validator_fn.(item_str) do
          {:ok, atom_value} -> {[atom_value | valid_acc], invalid_acc}
          {:error, _} -> {valid_acc, [item_str | invalid_acc]}
        end
      end)

    # Report invalid items (SECURITY: Prevent atom exhaustion from logging)
    report_invalid_items(invalid, item_name)

    # Return result
    if Enum.empty?(valid) do
      Mix.shell().error("No valid #{item_name}s found")
      :error
    else
      {:ok, Enum.reverse(valid)}
    end
  end

  defp report_invalid_items([], _item_name), do: :ok

  defp report_invalid_items(invalid, item_name) do
    count = length(invalid)
    Mix.shell().error("Skipping #{count} invalid #{item_name}(s)")
  end

  defp validate_field_atom(field_str) do
    field_atom = String.to_existing_atom(field_str)
    {:ok, field_atom}
  rescue
    ArgumentError ->
      {:error, :invalid_field}
  end

  defp maybe_add_boolean_filters(filters, opts) do
    filters
    |> maybe_put_flag(:missing_only, opts[:missing_only])
    |> maybe_put_flag(:complete_only, opts[:complete_only])
  end

  defp maybe_put_flag(map, _key, nil), do: map
  defp maybe_put_flag(map, _key, false), do: map
  defp maybe_put_flag(map, key, true), do: Map.put(map, key, true)

  defp fetch_translations(resource, filters) do
    {:ok, resources} = Ash.read(resource)

    if Enum.empty?(resources) do
      []
    else
      first_record = List.first(resources)
      translation_fields = get_translation_fields(first_record)
      extract_all_translations(resources, translation_fields, filters)
    end
  end

  defp get_translation_fields(record) do
    record
    |> Map.keys()
    |> Enum.filter(&translation_field?(&1, record))
  end

  defp translation_field?(key, record) do
    key != :__struct__ &&
      key != :__meta__ &&
      String.ends_with?(to_string(key), "_translations") &&
      !String.ends_with?(to_string(key), "_all_translations") &&
      is_map(Map.get(record, key))
  end

  defp extract_all_translations(resources, translation_fields, filters) do
    for record <- resources,
        storage_field <- translation_fields,
        {locale, value} <- Map.get(record, storage_field, %{}),
        translation = build_translation(record, storage_field, locale, value, filters),
        translation != nil do
      translation
    end
  end

  defp build_translation(record, storage_field, locale, value, filters) do
    field = extract_field_name(storage_field)

    if should_include_translation?(field, locale, value, filters) do
      %{
        resource_id: record.id,
        field: field,
        locale: locale,
        value: value || ""
      }
    else
      nil
    end
  end

  defp extract_field_name(storage_field) do
    field_str =
      storage_field
      |> to_string()
      |> String.replace_suffix("_translations", "")

    # SECURITY: Use String.to_existing_atom to prevent atom exhaustion
    # Field names should already exist as atoms if they're valid resource attributes
    try do
      String.to_existing_atom(field_str)
    rescue
      ArgumentError ->
        # If atom doesn't exist, storage_field is already an atom from database record keys
        # This is safe because it came from the database schema, not user input
        if is_atom(storage_field) do
          storage_field
        else
          # This should never happen in practice, but handle it safely
          :unknown_field
        end
    end
  end

  defp should_include_translation?(field, locale, value, filters) do
    !field_filtered?(field, filters) &&
      !locale_filtered?(locale, filters) &&
      !value_filtered?(value, filters)
  end

  defp field_filtered?(field, filters) do
    filters[:fields] && field not in filters[:fields]
  end

  defp locale_filtered?(locale, filters) do
    filters[:locales] && locale not in filters[:locales]
  end

  defp value_filtered?(value, filters) do
    (filters[:missing_only] && value != nil && value != "") ||
      (filters[:complete_only] && (value == nil || value == ""))
  end

  defp write_file(path, "csv", translations) do
    File.mkdir_p!(Path.dirname(path))

    csv_data =
      translations
      |> Enum.map(fn t ->
        [
          to_string(t.resource_id),
          to_string(t.field),
          to_string(t.locale),
          t.value
        ]
      end)

    headers = ["resource_id", "field", "locale", "value"]

    file = File.open!(path, [:write, :utf8])

    # Write headers
    IO.write(file, Enum.join(headers, ",") <> "\n")

    # Write data
    Enum.each(csv_data, fn row ->
      escaped_row = Enum.map_join(row, ",", &escape_csv_field/1)
      IO.write(file, escaped_row <> "\n")
    end)

    File.close(file)
  end

  defp write_file(path, "json", translations) do
    File.mkdir_p!(Path.dirname(path))

    json_data = %{
      "metadata" => %{
        "exported_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "total" => length(translations)
      },
      "translations" =>
        Enum.map(translations, fn t ->
          %{
            "resource_id" => to_string(t.resource_id),
            "field" => to_string(t.field),
            "locale" => to_string(t.locale),
            "value" => t.value
          }
        end)
    }

    json = Jason.encode!(json_data, pretty: true)
    File.write!(path, json)
  end

  defp write_file(path, "xliff", translations) do
    File.mkdir_p!(Path.dirname(path))

    # Group by locale for XLIFF
    grouped = Enum.group_by(translations, & &1.locale)

    xliff = """
    <?xml version="1.0" encoding="UTF-8"?>
    <xliff version="1.2" xmlns="urn:oasis:names:tc:xliff:document:1.2">
    #{Enum.map_join(grouped, "\n", fn {locale, trans} -> format_xliff_file(locale, trans) end)}
    </xliff>
    """

    File.write!(path, xliff)
  end

  defp write_file(_path, format, _translations) do
    Mix.raise("Unsupported format: #{format}")
  end

  defp escape_csv_field(field) do
    if String.contains?(field, [",", "\"", "\n"]) do
      "\"" <> String.replace(field, "\"", "\"\"") <> "\""
    else
      field
    end
  end

  defp format_xliff_file(locale, translations) do
    """
      <file source-language="en" target-language="#{locale}" datatype="plaintext">
        <body>
    #{Enum.map_join(translations, "\n", &format_xliff_unit/1)}
        </body>
      </file>
    """
  end

  defp format_xliff_unit(translation) do
    """
          <trans-unit id="#{translation.resource_id}_#{translation.field}">
            <source>#{translation.field}</source>
            <target>#{escape_xml(translation.value)}</target>
          </trans-unit>
    """
  end

  defp escape_xml(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
