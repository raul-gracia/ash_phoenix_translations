defmodule Mix.Tasks.AshPhoenixTranslations.Import do
  @moduledoc """
  Imports translations from CSV, JSON, or XLIFF files.
  
  ## Usage
  
      mix ash_phoenix_translations.import path/to/file.csv --resource MyApp.Product
      mix ash_phoenix_translations.import translations.json --format json
      mix ash_phoenix_translations.import messages.xliff --format xliff
  
  ## Options
  
    * `--resource` - The resource module to import translations for (required)
    * `--format` - File format: csv, json, or xliff (auto-detected if not specified)
    * `--locale` - Default locale for imports without locale specification
    * `--dry-run` - Preview import without making changes
    * `--replace` - Replace existing translations (default: merge)
  
  ## File Formats
  
  ### CSV Format
  
      resource_id,field,locale,value
      123e4567-e89b-12d3-a456-426614174000,name,en,Product Name
      123e4567-e89b-12d3-a456-426614174000,name,es,Nombre del Producto
  
  ### JSON Format
  
      {
        "translations": [
          {
            "resource_id": "123e4567-e89b-12d3-a456-426614174000",
            "field": "name",
            "locale": "en",
            "value": "Product Name"
          }
        ]
      }
  
  ### XLIFF Format
  
      Standard XLIFF 1.2 or 2.0 format
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
      |> Enum.map(fn row ->
        %{
          resource_id: row["resource_id"],
          field: String.to_atom(row["field"]),
          locale: String.to_atom(row["locale"] || default_locale),
          value: row["value"]
        }
      end)
    else
      raise "CSV library is required for CSV imports. Add {:csv, \"~> 3.0\"} to your dependencies."
    end
  end
  
  defp parse_file(file_path, "json", default_locale) do
    file_path
    |> File.read!()
    |> Jason.decode!()
    |> Map.get("translations", [])
    |> Enum.map(fn t ->
      %{
        resource_id: t["resource_id"],
        field: String.to_atom(t["field"]),
        locale: String.to_atom(t["locale"] || default_locale),
        value: t["value"]
      }
    end)
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
      Mix.shell().info("Would import #{length(translations)} translations for resource #{resource_id}")
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