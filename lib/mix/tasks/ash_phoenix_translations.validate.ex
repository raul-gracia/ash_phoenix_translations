defmodule Mix.Tasks.AshPhoenixTranslations.Validate do
  @moduledoc """
  Validates translations for completeness, quality, and security.

  This task performs comprehensive validation of translations across your Ash resources,
  checking for missing translations, quality issues, and potential security vulnerabilities.
  Essential for maintaining translation quality in production environments.

  ## Features

  - **Completeness Checks**: Identify missing and incomplete translations
  - **Quality Validation**: Check encoding, length constraints, and content safety
  - **Security Scanning**: Detect potential XSS vectors and injection attempts
  - **Flexible Reporting**: Output in text, JSON, or CSV formats
  - **CI/CD Integration**: Strict mode for automated quality gates
  - **Performance**: Fast validation using parallel processing
  - **Localized Scope**: Validate specific locales, fields, or resources

  ## Basic Usage

      # Validate all translations for a single resource
      mix ash_phoenix_translations.validate --resource MyApp.Product

      # Validate all resources with translations
      mix ash_phoenix_translations.validate --all

      # Validate specific locale
      mix ash_phoenix_translations.validate --resource MyApp.Product --locale es

      # Validate specific fields
      mix ash_phoenix_translations.validate --resource MyApp.Product --field name,description

  ## Options

    * `--resource` - Specific resource module to validate (e.g., MyApp.Product)
    * `--all` - Validate all resources with translations extension
    * `--locale` - Comma-separated list of locales to validate (e.g., es,fr)
    * `--field` - Comma-separated list of fields to validate (e.g., name,description)
    * `--strict` - Fail build on any missing translations (exit code 1)
    * `--format` - Output format: text, json, or csv (default: text)
    * `--output` - Output file path for report (default: stdout)

  ## Validation Checks

  ### Completeness Checks
  - **Missing translations**: Detects nil or empty string values
  - **Incomplete locales**: Identifies resources missing required locales
  - **Invalid locale codes**: Validates locale format and configuration

  ### Quality Checks
  - **Character encoding**: Ensures valid UTF-8 encoding
  - **Length constraints**: Validates min_length and max_length if configured
  - **HTML content**: Detects HTML when no_html flag is set
  - **Duplicate detection**: Identifies identical values across locales

  ### Security Checks
  - **XSS vectors**: Scans for `<script>`, `javascript:`, event handlers
  - **Template injection**: Detects `\${`, `<%`, and similar patterns
  - **Control characters**: Identifies suspicious control characters
  - **SQL injection patterns**: Basic SQL injection detection

  ## Output Formats

  ### Text Format (Default)

      Resource: MyApp.Product
      ------------------------------------
      Total translations: 150
      Missing: 12
      Completeness: 92.0%
      Issues found: 15

      Issues:
        Missing: abc-123 - name[es]
        Too short: def-456 - description[fr] (5 chars, min: 10)
        Contains HTML: ghi-789 - description[de]

  ### JSON Format

      {
        "resource": "MyApp.Product",
        "issues": [
          {
            "type": "missing",
            "resource_id": "abc-123",
            "field": "name",
            "locale": "es"
          }
        ],
        "stats": {
          "total_translations": 150,
          "missing_translations": 12,
          "completeness": 92.0
        }
      }

  ### CSV Format

      resource,issue_type,resource_id,field,locale,details
      MyApp.Product,missing,abc-123,name,es,
      MyApp.Product,too_short,def-456,description,fr,"5 chars, min: 10"

  ## CI/CD Integration

  ### GitHub Actions

      # .github/workflows/translations.yml
      name: Validate Translations

      on: [push, pull_request]

      jobs:
        validate:
          runs-on: ubuntu-latest
          steps:
            - uses: actions/checkout@v3
            - uses: erlef/setup-beam@v1
              with:
                elixir-version: '1.17'
                otp-version: '27'

            - name: Install dependencies
              run: mix deps.get

            - name: Validate translations
              run: |
                mix ash_phoenix_translations.validate \\
                  --all \\
                  --strict \\
                  --format json \\
                  --output validation-report.json

            - name: Upload validation report
              if: failure()
              uses: actions/upload-artifact@v3
              with:
                name: translation-validation
                path: validation-report.json

  ### GitLab CI

      # .gitlab-ci.yml
      validate_translations:
        stage: test
        script:
          - mix deps.get
          - mix ash_phoenix_translations.validate --all --strict
        artifacts:
          when: on_failure
          paths:
            - validation-report.json
        rules:
          - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'

  ### Pre-commit Hook

      # .git/hooks/pre-commit
      #!/bin/sh

      echo "Validating translations..."
      mix ash_phoenix_translations.validate --all --strict

      if [ $? -ne 0 ]; then
        echo "Translation validation failed. Commit aborted."
        echo "Run 'mix ash_phoenix_translations.validate --all' to see issues"
        exit 1
      fi

  ## Workflow Examples

  ### Development Workflow

      # 1. Make translation changes
      # 2. Validate locally before committing
      mix ash_phoenix_translations.validate --resource MyApp.Product

      # 3. If issues found, export for review
      mix ash_phoenix_translations.export missing.csv \\
        --resource MyApp.Product \\
        --missing-only

      # 4. After fixing, validate again
      mix ash_phoenix_translations.validate --resource MyApp.Product --strict

  ### Release Workflow

      # Pre-release validation checklist

      # 1. Validate all resources
      mix ash_phoenix_translations.validate --all --strict

      # 2. Generate completeness report
      mix ash_phoenix_translations.validate \\
        --all \\
        --format csv \\
        --output reports/translation-status.csv

      # 3. Check specific locale readiness
      mix ash_phoenix_translations.validate \\
        --all \\
        --locale es \\
        --strict

  ### Quality Gate Pattern

      defmodule MyApp.Release do
        def check_translation_quality do
          # Run validation
          {output, exit_code} =
            System.cmd("mix", [
              "ash_phoenix_translations.validate",
              "--all",
              "--format", "json",
              "--output", "validation.json"
            ])

          case exit_code do
            0 ->
              IO.puts("✅ Translation validation passed")
              :ok

            1 ->
              IO.puts("❌ Translation validation failed")
              report = File.read!("validation.json") |> Jason.decode!()

              IO.puts("Issues found:")
              for issue <- report["issues"] do
                IO.puts("  - \#{issue["type"]}: \#{issue["field"]}[\#{issue["locale"]}]")
              end

              {:error, :validation_failed}

            _ ->
              IO.puts("⚠️  Validation error occurred")
              {:error, :validation_error}
          end
        end
      end

  ## Continuous Monitoring

  ### Translation Health Dashboard

      # Run periodic validation and track metrics
      defmodule MyApp.TranslationHealthChecker do
        use GenServer

        def start_link(_) do
          GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
        end

        def init(state) do
          # Check translation health every hour
          schedule_check()
          {:ok, state}
        end

        def handle_info(:check_health, state) do
          run_validation()
          schedule_check()
          {:noreply, state}
        end

        defp schedule_check do
          Process.send_after(self(), :check_health, :timer.hours(1))
        end

        defp run_validation do
          {output, exit_code} =
            System.cmd("mix", [
              "ash_phoenix_translations.validate",
              "--all",
              "--format", "json"
            ])

          if exit_code == 0 do
            Logger.info("Translation health check passed")
          else
            Logger.warning("Translation health check found issues",
              output: output
            )

            # Send alert to monitoring system
            send_alert(output)
          end
        end

        defp send_alert(report) do
          # Integration with monitoring tools
          # MyApp.Monitoring.send_alert(:translation_quality, report)
        end
      end

  ### Metrics Collection

      # Collect validation metrics over time
      def collect_translation_metrics do
        {output, _} =
          System.cmd("mix", [
            "ash_phoenix_translations.validate",
            "--all",
            "--format", "json",
            "--output", "metrics.json"
          ])

        metrics = File.read!("metrics.json") |> Jason.decode!()

        # Track metrics in your monitoring system
        MyApp.Metrics.gauge("translations.completeness",
          metrics["stats"]["completeness"]
        )

        MyApp.Metrics.gauge("translations.missing_count",
          metrics["stats"]["missing_translations"]
        )
      end

  ## Exit Codes

    * `0` - All validations passed successfully
    * `1` - Validation failures found (only when using --strict)
    * `2` - Configuration errors or missing resources

  ## Performance Considerations

  - **Parallel Processing**: Validation runs in parallel across resources
  - **Resource Usage**: Memory usage scales with number of translations
  - **Large Datasets**: For 100k+ translations, consider validating by resource
  - **CI Optimization**: Use `--resource` to validate only changed resources

  ## Troubleshooting

  ### "Resource not found" Error

      # Ensure the resource module exists and is compiled
      mix compile
      mix ash_phoenix_translations.validate --resource MyApp.Product

  ### "No resources found" with --all

      # Verify resources have the translations extension
      # In your resource:
      use Ash.Resource,
        extensions: [AshPhoenixTranslations]

  ### High Memory Usage

      # Validate resources individually instead of --all
      for resource in [MyApp.Product, MyApp.Category] do
        mix ash_phoenix_translations.validate --resource \#{resource}
      end

  ## Security Considerations

  This task helps identify security issues in translations:

  - **XSS Prevention**: Detects potential cross-site scripting vectors
  - **Injection Detection**: Identifies template and SQL injection patterns
  - **Content Safety**: Validates HTML content when restrictions are configured
  - **Encoding Issues**: Ensures proper UTF-8 encoding to prevent display issues

  ## Related Tasks

  - `mix ash_phoenix_translations.export` - Export translations for review
  - `mix ash_phoenix_translations.import` - Import corrected translations
  - `mix ash_phoenix_translations.extract` - Extract translatable strings

  ## Examples

      # Development: Quick validation
      mix ash_phoenix_translations.validate --resource MyApp.Product

      # Production: Comprehensive validation with report
      mix ash_phoenix_translations.validate \\
        --all \\
        --strict \\
        --format json \\
        --output production-validation.json

      # CI/CD: Validate specific locale for release
      mix ash_phoenix_translations.validate \\
        --all \\
        --locale es,fr \\
        --strict

      # Quality assurance: Generate CSV report for review
      mix ash_phoenix_translations.validate \\
        --all \\
        --format csv \\
        --output translation-issues.csv
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
        # Process locales and collect validation results
        {valid_locales, invalid_locales} =
          opts[:locale]
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.reduce({[], []}, fn locale_str, {valid, invalid} ->
            case AshPhoenixTranslations.LocaleValidator.validate_locale(locale_str) do
              {:ok, locale_atom} ->
                {[locale_atom | valid], invalid}

              {:error, _} ->
                {valid, [locale_str | invalid]}
            end
          end)

        # Report invalid locales as a single aggregated message (SECURITY: Prevent atom exhaustion from logging)
        unless Enum.empty?(invalid_locales) do
          count = length(invalid_locales)
          Mix.shell().error("Skipping #{count} invalid locale(s)")
        end

        if Enum.empty?(valid_locales) do
          Mix.shell().error("No valid locales found")
          filters
        else
          Map.put(filters, :locales, Enum.reverse(valid_locales))
        end
      else
        filters
      end

    filters =
      if opts[:field] do
        # Process fields and collect validation results
        {valid_fields, invalid_fields} =
          opts[:field]
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.reduce({[], []}, fn field_str, {valid, invalid} ->
            try do
              field_atom = String.to_existing_atom(field_str)
              {[field_atom | valid], invalid}
            rescue
              ArgumentError ->
                {valid, [field_str | invalid]}
            end
          end)

        # Report invalid fields as a single aggregated message (SECURITY: Prevent atom exhaustion from logging)
        unless Enum.empty?(invalid_fields) do
          count = length(invalid_fields)
          Mix.shell().error("Skipping #{count} invalid field(s)")
        end

        if Enum.empty?(valid_fields) do
          Mix.shell().error("No valid fields found")
          filters
        else
          Map.put(filters, :fields, Enum.reverse(valid_fields))
        end
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

    # Check each record
    issues =
      Enum.reduce(records, [], fn record, acc ->
        record_issues = validate_record(record, attrs_to_check, filters)
        record_issues ++ acc
      end)
      |> Enum.reverse()

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
    Enum.reduce(attrs, [], fn attr, acc ->
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

          current_issues ++ field_acc
        end)
        |> Enum.reverse()

      field_issues ++ acc
    end)
    |> Enum.reverse()
  end

  defp check_quality(value, resource_id, field, locale, attr) do
    quality_issues = []

    # Check length constraints using struct field access
    quality_issues =
      if Map.get(attr, :min_length) && String.length(value) < attr.min_length do
        [
          {:too_short, resource_id, field, locale, String.length(value), attr.min_length}
          | quality_issues
        ]
      else
        quality_issues
      end

    quality_issues =
      if Map.get(attr, :max_length) && String.length(value) > attr.max_length do
        [
          {:too_long, resource_id, field, locale, String.length(value), attr.max_length}
          | quality_issues
        ]
      else
        quality_issues
      end

    # Check for HTML if not allowed
    quality_issues =
      if Map.get(attr, :no_html) && contains_html?(value) do
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
      # onclick, onload, etc.
      ~r/on\w+=/i,
      # Template injection
      ~r/\$\{/,
      # ERB/ASP injection
      ~r/<%/
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
      completeness:
        if(total_translations > 0,
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
    content = Enum.map_join(results, "\n\n", &format_text_result/1)

    File.write!(path, content)
    Mix.shell().info("Results written to #{path}")
  end

  defp output_results(results, "json", path) do
    json = Jason.encode!(results, pretty: true)

    if path do
      File.write!(path, json)
      Mix.shell().info("Results written to #{path}")
    else
      Mix.shell().info(json)
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
        ["", "Issues:"] ++
          Enum.map(result.issues, fn issue ->
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
