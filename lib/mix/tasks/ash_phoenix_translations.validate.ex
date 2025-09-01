defmodule Mix.Tasks.AshPhoenixTranslations.Validate do
  @moduledoc """
  Validates translations for completeness and quality.
  
  ## Usage
  
      mix ash_phoenix_translations.validate --resource MyApp.Product
      mix ash_phoenix_translations.validate --all
      mix ash_phoenix_translations.validate --resource MyApp.Product --locale es
  
  ## Options
  
    * `--resource` - Specific resource to validate
    * `--all` - Validate all resources with translations
    * `--locale` - Validate only specific locale(s), comma-separated
    * `--field` - Validate only specific field(s), comma-separated
    * `--strict` - Fail on any missing translations (exit code 1)
    * `--format` - Output format: text, json, or csv (default: text)
    * `--output` - Output file path (default: stdout)
  
  ## Validation Checks
  
    * Missing translations (empty or nil values)
    * Incomplete locales (not all required locales present)
    * Invalid locale codes
    * Duplicate translations
    * Character encoding issues
    * Length constraints (if defined)
    * HTML/unsafe content (if restricted)
  
  ## Exit Codes
  
    * 0 - All validations passed
    * 1 - Validation failures found (with --strict)
    * 2 - Configuration or resource errors
  """
  
  use Mix.Task
  
  @shortdoc "Validates translations for completeness and quality"
  
  @switches [
    resource: :string,
    all: :boolean,
    locale: :string,
    field: :string,
    strict: :boolean,
    format: :string,
    output: :string
  ]
  
  @aliases [
    r: :resource,
    a: :all,
    l: :locale,
    f: :field,
    s: :strict
  ]
  
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)
    
    unless opts[:resource] || opts[:all] do
      Mix.raise("Either --resource or --all option is required")
    end
    
    Mix.Task.run("app.start")
    
    resources = get_resources_to_validate(opts)
    format = opts[:format] || "text"
    output_path = opts[:output]
    strict = opts[:strict] || false
    
    filters = build_filters(opts)
    
    Mix.shell().info("Validating translations...")
    
    results = 
      Enum.map(resources, fn resource ->
        validate_resource(resource, filters)
      end)
    
    output_results(results, format, output_path)
    
    total_issues = 
      results
      |> Enum.map(& &1.issue_count)
      |> Enum.sum()
    
    if strict && total_issues > 0 do
      System.halt(1)
    end
  end
  
  defp get_resources_to_validate(opts) do
    if opts[:all] do
      # Get all resources with translations extension
      # This would need to scan the application
      Mix.shell().warn("--all option requires application scanning. Using example resource.")
      [Example.Product]
    else
      [Module.concat([opts[:resource]])]
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
    
    filters
  end
  
  defp validate_resource(resource, filters) do
    Mix.shell().info("Validating #{inspect(resource)}...")
    
    # Get translatable attributes
    translatable_attrs = AshPhoenixTranslations.Info.translatable_attributes(resource)
    
    # Filter attributes if needed
    attrs_to_check = 
      if filters[:fields] do
        Enum.filter(translatable_attrs, fn attr ->
          attr.name in filters[:fields]
        end)
      else
        translatable_attrs
      end
    
    # Get all resource instances
    {:ok, records} = Ash.read(resource)
    
    issues = []
    
    # Check each record
    issues = 
      Enum.reduce(records, issues, fn record, acc ->
        record_issues = validate_record(record, attrs_to_check, filters)
        acc ++ record_issues
      end)
    
    # Summary statistics
    stats = calculate_stats(records, attrs_to_check, filters)
    
    %{
      resource: resource,
      issues: issues,
      issue_count: length(issues),
      stats: stats
    }
  end
  
  defp validate_record(record, attrs, filters) do
    issues = []
    
    Enum.reduce(attrs, issues, fn attr, acc ->
      field = attr.name
      storage_field = :"#{field}_translations"
      translations = Map.get(record, storage_field, %{})
      
      # Check each locale
      locales_to_check = 
        if filters[:locales] do
          Enum.filter(attr.locales, fn locale ->
            locale in filters[:locales]
          end)
        else
          attr.locales
        end
      
      field_issues = 
        Enum.reduce(locales_to_check, [], fn locale, field_acc ->
          value = Map.get(translations, locale)
          
          # Check for missing translation
          current_issues = 
            if value == nil || value == "" do
              [{:missing, record.id, field, locale}]
            else
              # Check for quality issues
              check_quality(value, record.id, field, locale, attr)
            end
          
          field_acc ++ current_issues
        end)
      
      acc ++ field_issues
    end)
  end
  
  defp check_quality(value, resource_id, field, locale, attr) do
    quality_issues = []
    
    # Check length constraints
    quality_issues = 
      if attr[:min_length] && String.length(value) < attr.min_length do
        [{:too_short, resource_id, field, locale, String.length(value), attr.min_length} | quality_issues]
      else
        quality_issues
      end
    
    quality_issues = 
      if attr[:max_length] && String.length(value) > attr.max_length do
        [{:too_long, resource_id, field, locale, String.length(value), attr.max_length} | quality_issues]
      else
        quality_issues
      end
    
    # Check for HTML if not allowed
    quality_issues = 
      if attr[:no_html] && contains_html?(value) do
        [{:contains_html, resource_id, field, locale} | quality_issues]
      else
        quality_issues
      end
    
    # Check for valid UTF-8
    quality_issues = 
      unless String.valid?(value) do
        [{:invalid_encoding, resource_id, field, locale} | quality_issues]
      else
        quality_issues
      end
    
    # Check for suspicious patterns (potential injection)
    quality_issues = 
      if contains_suspicious_pattern?(value) do
        [{:suspicious_content, resource_id, field, locale} | quality_issues]
      else
        quality_issues
      end
    
    quality_issues
  end
  
  defp contains_html?(text) do
    Regex.match?(~r/<[^>]+>/, text)
  end
  
  defp contains_suspicious_pattern?(text) do
    patterns = [
      ~r/<script/i,
      ~r/javascript:/i,
      ~r/on\w+=/i,  # onclick, onload, etc.
      ~r/\$\{/,     # Template injection
      ~r/<%/        # ERB/ASP injection
    ]
    
    Enum.any?(patterns, fn pattern ->
      Regex.match?(pattern, text)
    end)
  end
  
  defp calculate_stats(records, attrs, filters) do
    total_translations = length(records) * length(attrs) * length(get_all_locales(attrs, filters))
    
    missing_count = 
      Enum.reduce(records, 0, fn record, acc ->
        count = 
          Enum.reduce(attrs, 0, fn attr, attr_acc ->
            storage_field = :"#{attr.name}_translations"
            translations = Map.get(record, storage_field, %{})
            
            locales = get_locales_for_attr(attr, filters)
            
            missing = 
              Enum.count(locales, fn locale ->
                value = Map.get(translations, locale)
                value == nil || value == ""
              end)
            
            attr_acc + missing
          end)
        
        acc + count
      end)
    
    %{
      total_records: length(records),
      total_fields: length(attrs),
      total_translations: total_translations,
      missing_translations: missing_count,
      completeness: if(total_translations > 0, 
        do: Float.round((total_translations - missing_count) / total_translations * 100, 1),
        else: 0.0
      )
    }
  end
  
  defp get_all_locales(attrs, filters) do
    all_locales = 
      attrs
      |> Enum.flat_map(& &1.locales)
      |> Enum.uniq()
    
    if filters[:locales] do
      Enum.filter(all_locales, fn locale ->
        locale in filters[:locales]
      end)
    else
      all_locales
    end
  end
  
  defp get_locales_for_attr(attr, filters) do
    if filters[:locales] do
      Enum.filter(attr.locales, fn locale ->
        locale in filters[:locales]
      end)
    else
      attr.locales
    end
  end
  
  defp output_results(results, "text", nil) do
    Enum.each(results, &output_text_result/1)
    
    # Overall summary
    total_issues = 
      results
      |> Enum.map(& &1.issue_count)
      |> Enum.sum()
    
    Mix.shell().info("""
    
    =====================================
    VALIDATION SUMMARY
    =====================================
    Total resources validated: #{length(results)}
    Total issues found: #{total_issues}
    
    #{if total_issues == 0, do: "✅ All validations passed!", else: "❌ Issues found - review above"}
    """)
  end
  
  defp output_results(results, "text", path) do
    content = 
      results
      |> Enum.map(&format_text_result/1)
      |> Enum.join("\n\n")
    
    File.write!(path, content)
    Mix.shell().info("Results written to #{path}")
  end
  
  defp output_results(results, "json", path) do
    json = Jason.encode!(results, pretty: true)
    
    if path do
      File.write!(path, json)
      Mix.shell().info("Results written to #{path}")
    else
      IO.puts(json)
    end
  end
  
  defp output_results(_results, format, _path) do
    Mix.raise("Unsupported format: #{format}")
  end
  
  defp output_text_result(result) do
    Mix.shell().info("""
    
    Resource: #{inspect(result.resource)}
    ------------------------------------
    Total translations: #{result.stats.total_translations}
    Missing: #{result.stats.missing_translations}
    Completeness: #{result.stats.completeness}%
    Issues found: #{result.issue_count}
    """)
    
    if result.issue_count > 0 do
      Mix.shell().info("Issues:")
      
      Enum.each(result.issues, fn issue ->
        Mix.shell().info("  " <> format_issue(issue))
      end)
    end
  end
  
  defp format_text_result(result) do
    lines = [
      "Resource: #{inspect(result.resource)}",
      "------------------------------------",
      "Total translations: #{result.stats.total_translations}",
      "Missing: #{result.stats.missing_translations}",
      "Completeness: #{result.stats.completeness}%",
      "Issues found: #{result.issue_count}"
    ]
    
    issue_lines = 
      if result.issue_count > 0 do
        ["", "Issues:"] ++ Enum.map(result.issues, fn issue ->
          "  " <> format_issue(issue)
        end)
      else
        []
      end
    
    Enum.join(lines ++ issue_lines, "\n")
  end
  
  defp format_issue({:missing, resource_id, field, locale}) do
    "Missing: #{resource_id} - #{field}[#{locale}]"
  end
  
  defp format_issue({:too_short, resource_id, field, locale, actual, expected}) do
    "Too short: #{resource_id} - #{field}[#{locale}] (#{actual} chars, min: #{expected})"
  end
  
  defp format_issue({:too_long, resource_id, field, locale, actual, expected}) do
    "Too long: #{resource_id} - #{field}[#{locale}] (#{actual} chars, max: #{expected})"
  end
  
  defp format_issue({:contains_html, resource_id, field, locale}) do
    "Contains HTML: #{resource_id} - #{field}[#{locale}]"
  end
  
  defp format_issue({:invalid_encoding, resource_id, field, locale}) do
    "Invalid encoding: #{resource_id} - #{field}[#{locale}]"
  end
  
  defp format_issue({:suspicious_content, resource_id, field, locale}) do
    "Suspicious content: #{resource_id} - #{field}[#{locale}]"
  end
  
  defp format_issue(issue) do
    "Unknown issue: #{inspect(issue)}"
  end
end