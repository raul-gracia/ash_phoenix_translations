defmodule Mix.Tasks.AshPhoenixTranslations.Export do
  @moduledoc """
  Exports translations to CSV, JSON, or XLIFF files.

  ## Usage

      mix ash_phoenix_translations.export output.csv --resource MyApp.Product
      mix ash_phoenix_translations.export translations.json --format json --locale es
      mix ash_phoenix_translations.export messages.xliff --format xliff

  ## Options

    * `--resource` - The resource module to export translations from (required)
    * `--format` - Output format: csv, json, or xliff (auto-detected if not specified)
    * `--locale` - Export only specific locale(s), comma-separated
    * `--field` - Export only specific field(s), comma-separated
    * `--missing-only` - Export only missing translations
    * `--complete-only` - Export only complete translations

  ## Examples

      # Export all translations for a resource to CSV
      mix ash_phoenix_translations.export products.csv --resource MyApp.Product
      
      # Export only Spanish translations to JSON
      mix ash_phoenix_translations.export es.json --resource MyApp.Product --locale es
      
      # Export only missing translations
      mix ash_phoenix_translations.export missing.csv --resource MyApp.Product --missing-only
      
      # Export specific fields
      mix ash_phoenix_translations.export names.csv --resource MyApp.Product --field name,description
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
    filters = %{}

    filters =
      if opts[:locale] do
        locales =
          opts[:locale]
          |> String.split(",")
          |> Enum.map(&String.to_atom/1)

        Map.put(filters, :locales, locales)
      else
        filters
      end

    filters =
      if opts[:field] do
        fields =
          opts[:field]
          |> String.split(",")
          |> Enum.map(&String.to_atom/1)

        Map.put(filters, :fields, fields)
      else
        filters
      end

    filters =
      if opts[:missing_only] do
        Map.put(filters, :missing_only, true)
      else
        filters
      end

    filters =
      if opts[:complete_only] do
        Map.put(filters, :complete_only, true)
      else
        filters
      end

    filters
  end

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
    storage_field
    |> to_string()
    |> String.replace_suffix("_translations", "")
    |> String.to_atom()
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
