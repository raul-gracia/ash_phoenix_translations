# Import/Export Guide

This guide covers importing and exporting translations for bulk operations and data migration.

## Overview

AshPhoenixTranslations provides comprehensive import/export functionality to help manage translations at scale. Whether you're migrating from another system, preparing translations for external translators, or performing bulk updates, the import/export tools streamline these workflows.

## Export Functionality

### Basic Export

Export all translations from a resource to JSON format:

```bash
mix ash_phoenix_translations.export MyApp.Product --output translations.json
```

### Export Options

```bash
# Export specific locales
mix ash_phoenix_translations.export MyApp.Product --locales en,es,fr

# Export specific fields
mix ash_phoenix_translations.export MyApp.Product --fields name,description

# Export to CSV format
mix ash_phoenix_translations.export MyApp.Product --format csv --output translations.csv

# Include metadata
mix ash_phoenix_translations.export MyApp.Product --include-metadata
```

### Export Formats

#### JSON Format

Default format, preserves full structure:

```json
{
  "products": [
    {
      "id": "123e4567-e89b-12d3-a456-426614174000",
      "translations": {
        "name": {
          "en": "Gaming Laptop",
          "es": "Portátil Gaming",
          "fr": "Ordinateur Portable Gaming"
        },
        "description": {
          "en": "High-performance laptop",
          "es": "Portátil de alto rendimiento",
          "fr": "Ordinateur portable haute performance"
        }
      }
    }
  ]
}
```

#### CSV Format

Flat structure for spreadsheet compatibility:

```csv
id,field,locale,value
123e4567-e89b-12d3-a456-426614174000,name,en,Gaming Laptop
123e4567-e89b-12d3-a456-426614174000,name,es,Portátil Gaming
123e4567-e89b-12d3-a456-426614174000,name,fr,Ordinateur Portable Gaming
```

## Import Functionality

### Basic Import

Import translations from a JSON file:

```bash
mix ash_phoenix_translations.import MyApp.Product translations.json
```

### Import Options

```bash
# Merge with existing translations
mix ash_phoenix_translations.import MyApp.Product translations.json --merge

# Replace all translations
mix ash_phoenix_translations.import MyApp.Product translations.json --replace

# Dry run to preview changes
mix ash_phoenix_translations.import MyApp.Product translations.json --dry-run

# Import from CSV
mix ash_phoenix_translations.import MyApp.Product translations.csv --format csv
```

### Import Strategies

#### Merge Strategy (Default)

- Preserves existing translations
- Updates only provided translations
- Adds new translations without removing others

#### Replace Strategy

- Replaces all translations for affected records
- Removes translations not in import file
- Use with caution in production

## Programmatic Import/Export

### Export in Code

```elixir
# Export all products
{:ok, json} = AshPhoenixTranslations.Export.to_json(MyApp.Product)

# Export with filters
{:ok, json} = AshPhoenixTranslations.Export.to_json(
  MyApp.Product,
  locales: [:en, :es],
  fields: [:name, :description],
  filter: [category: "electronics"]
)

# Export to CSV
{:ok, csv} = AshPhoenixTranslations.Export.to_csv(MyApp.Product)
```

### Import in Code

```elixir
# Import from JSON
{:ok, results} = AshPhoenixTranslations.Import.from_json(
  MyApp.Product,
  json_data,
  strategy: :merge
)

# Import from CSV
{:ok, results} = AshPhoenixTranslations.Import.from_csv(
  MyApp.Product,
  csv_data
)

# Batch import with validation
case AshPhoenixTranslations.Import.validate_and_import(MyApp.Product, data) do
  {:ok, %{imported: count, errors: []}} ->
    IO.puts("Successfully imported #{count} translations")
  
  {:error, %{imported: count, errors: errors}} ->
    IO.puts("Imported #{count}, failed #{length(errors)}")
    Enum.each(errors, &IO.inspect/1)
end
```

## Bulk Operations

### Batch Translation Updates

```elixir
# Update all products in a category
AshPhoenixTranslations.BulkUpdate.update_category(
  "electronics",
  %{
    name_translations: %{
      en: fn current -> "NEW: " <> current end,
      es: fn current -> "NUEVO: " <> current end
    }
  }
)
```

### Mass Translation Validation

```elixir
# Validate all translations
{:ok, report} = AshPhoenixTranslations.Validator.validate_all(MyApp.Product)

# Check completeness
missing = AshPhoenixTranslations.Validator.find_missing_translations(
  MyApp.Product,
  required_locales: [:en, :es, :fr]
)
```

## Migration Workflows

### From Database Backend to Gettext

```bash
# 1. Export current database translations
mix ash_phoenix_translations.export MyApp.Product --output db_translations.json

# 2. Convert to Gettext format
mix ash_phoenix_translations.convert db_translations.json --to gettext

# 3. Generate .po files
mix ash_phoenix_translations.generate_po_files
```

### From Legacy System

```elixir
# Custom migration script
defmodule TranslationMigrator do
  def migrate_from_legacy do
    legacy_data
    |> transform_to_ash_format()
    |> AshPhoenixTranslations.Import.from_json(MyApp.Product)
  end
  
  defp transform_to_ash_format(legacy_data) do
    # Transform legacy format to AshPhoenixTranslations format
  end
end
```

## External Translator Workflow

### Preparing Files for Translators

```bash
# Export untranslated content
mix ash_phoenix_translations.export MyApp.Product \
  --missing-only \
  --locales es,fr,de \
  --format xlsx \
  --output for_translation.xlsx
```

### Processing Translator Returns

```bash
# Validate returned translations
mix ash_phoenix_translations.validate translated.xlsx

# Preview changes
mix ash_phoenix_translations.import MyApp.Product translated.xlsx \
  --dry-run \
  --show-diff

# Import validated translations
mix ash_phoenix_translations.import MyApp.Product translated.xlsx \
  --backup-first
```

## Performance Considerations

### Large Dataset Exports

```elixir
# Stream export for large datasets
AshPhoenixTranslations.Export.stream(MyApp.Product)
|> Stream.chunk_every(1000)
|> Stream.each(&process_chunk/1)
|> Stream.run()
```

### Chunked Imports

```elixir
# Import in chunks to avoid memory issues
AshPhoenixTranslations.Import.chunked_import(
  MyApp.Product,
  large_dataset,
  chunk_size: 500,
  parallel: true
)
```

## Audit Trail

### Track Import/Export Operations

```elixir
# Enable audit logging
config :ash_phoenix_translations,
  audit_imports: true,
  audit_exports: true

# Query audit log
AshPhoenixTranslations.Audit.list_operations(
  type: :import,
  resource: MyApp.Product,
  since: ~D[2024-01-01]
)
```

## Best Practices

1. **Always Backup Before Import**
   ```bash
   mix ash_phoenix_translations.backup MyApp.Product
   mix ash_phoenix_translations.import MyApp.Product new_translations.json
   ```

2. **Validate Before Production Import**
   ```bash
   mix ash_phoenix_translations.import MyApp.Product translations.json --dry-run
   ```

3. **Use Appropriate Formats**
   - JSON for full fidelity
   - CSV for translator-friendly editing
   - XLSX for non-technical users

4. **Monitor Import Performance**
   ```elixir
   {:ok, stats} = AshPhoenixTranslations.Import.with_stats(
     MyApp.Product,
     data
   )
   IO.inspect(stats.timing)
   ```

## Troubleshooting

### Common Issues

**Large File Imports Timing Out**
- Use chunked imports
- Increase timeout settings
- Process in background job

**Character Encoding Issues**
- Ensure UTF-8 encoding
- Use `--encoding utf8` flag
- Check CSV delimiter settings

**Memory Issues with Large Exports**
- Use streaming exports
- Export in batches
- Increase BEAM memory limits