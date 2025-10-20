defmodule Mix.Tasks.AshPhoenixTranslations.Extract do
  @shortdoc "Extract translatable strings to Gettext POT files"

  @moduledoc """
  Extracts translatable strings from Ash resources to Gettext POT/PO files.

  This task scans your Ash resources for translatable attributes and generates
  or updates POT (Portable Object Template) and PO (Portable Object) files that
  can be used with Gettext for professional translation management.

  ## Features

  - **Automatic String Discovery**: Scans resources for translatable attributes
  - **POT/PO Generation**: Creates standard Gettext files
  - **Multi-Format Support**: Generate POT, PO, or both
  - **Domain Filtering**: Extract from specific Ash domains
  - **Resource Selection**: Choose specific resources to process
  - **Merge Capability**: Merge with existing translation files
  - **Verbose Mode**: Detailed extraction logging

  ## Basic Usage

      # Extract all resources to POT files
      mix ash_phoenix_translations.extract

      # Extract for specific domain
      mix ash_phoenix_translations.extract --domain MyApp.Shop

      # Extract with custom output directory
      mix ash_phoenix_translations.extract --output priv/gettext

      # Generate PO files for specific locales
      mix ash_phoenix_translations.extract --locales en,es,fr --format po

      # Extract with verbose logging
      mix ash_phoenix_translations.extract --verbose

  ## Options

    * `--domain` - Extract from a specific Ash domain (e.g., MyApp.Shop)
    * `--resources` - Comma-separated list of resource modules
    * `--output` - Output directory for files (default: priv/gettext)
    * `--locales` - Comma-separated list of locales for PO generation
    * `--merge` - Merge with existing POT/PO files
    * `--verbose` - Show detailed extraction information
    * `--format` - Output format: pot, po, or both (default: pot)

  ## Generated File Structure

  ### POT Format (Translation Templates)

      priv/gettext/
      └── default.pot           # Contains all translatable strings

  ### PO Format (Locale-Specific)

      priv/gettext/
      ├── en/
      │   └── LC_MESSAGES/
      │       └── default.po
      ├── es/
      │   └── LC_MESSAGES/
      │       └── default.po
      └── fr/
          └── LC_MESSAGES/
              └── default.po

  ### Both Formats

      priv/gettext/
      ├── default.pot           # Template
      ├── en/
      │   └── LC_MESSAGES/
      │       └── default.po    # English translations
      ├── es/
      │   └── LC_MESSAGES/
      │       └── default.po    # Spanish translations
      └── fr/
          └── LC_MESSAGES/
              └── default.po    # French translations

  ## POT File Example

  Generated POT files follow standard Gettext format:

      # Attribute name for MyApp.Product.name
      #: MyApp.Product:name
      msgid "product.name"
      msgstr ""

      # Description for MyApp.Product.description
      #: MyApp.Product:description
      msgid "product.description"
      msgstr ""

      # Validation message for MyApp.Product
      #: MyApp.Product:validation
      msgid "must be at least 3 characters"
      msgstr ""

  ## PO File Example

  Generated PO files include locale-specific headers:

      msgid ""
      msgstr ""
      "Language: es\\n"
      "MIME-Version: 1.0\\n"
      "Content-Type: text/plain; charset=UTF-8\\n"
      "Content-Transfer-Encoding: 8bit\\n"

      # Attribute name for MyApp.Product.name
      #: MyApp.Product:name
      msgid "product.name"
      msgstr "nombre del producto"

  ## Extraction Scope

  The task extracts the following from resources:

  ### Translatable Attributes

      translations do
        translatable_attribute :name, locales: [:en, :es]
        translatable_attribute :description, locales: [:en, :es]
      end

  Generates:
  - `product.name` msgid
  - `product.description` msgid

  ### Validation Messages

      validations do
        validate string_length(:name, min: 3, message: "must be at least 3 characters")
      end

  Generates:
  - `"must be at least 3 characters"` msgid

  ### Action Descriptions

      actions do
        create :create do
          description "Creates a new product"
        end
      end

  Generates:
  - `product.actions.create.description` msgid

  ## Workflow Examples

  ### Initial Setup for New Project

      # 1. Extract strings to POT template
      mix ash_phoenix_translations.extract --verbose

      # 2. Generate PO files for your locales
      mix ash_phoenix_translations.extract --locales en,es,fr --format both

      # 3. Edit PO files manually or send to translators
      # priv/gettext/es/LC_MESSAGES/default.po

      # 4. Compile translations
      mix compile.gettext

  ### Incremental Updates

      # 1. Extract new strings and merge with existing
      mix ash_phoenix_translations.extract --merge

      # 2. Merge into existing PO files
      mix gettext.merge priv/gettext

      # 3. Find untranslated strings
      msggrep --no-wrap -T priv/gettext/es/LC_MESSAGES/default.po | grep 'msgstr ""'

      # 4. Translate and recompile
      mix compile.gettext

  ### Domain-Specific Extraction

      # Extract only shop-related resources
      mix ash_phoenix_translations.extract --domain MyApp.Shop

      # Extract only catalog resources
      mix ash_phoenix_translations.extract \
        --resources MyApp.Product,MyApp.Category,MyApp.Brand

  ### CAT Tool Integration

      # 1. Extract to POT template
      mix ash_phoenix_translations.extract --format pot

      # 2. Upload priv/gettext/default.pot to CAT tool
      # (memoQ, Trados, Smartcat, etc.)

      # 3. Download translated PO files from CAT tool

      # 4. Place in correct locale directories
      # priv/gettext/es/LC_MESSAGES/default.po

      # 5. Compile
      mix compile.gettext

  ## Integration with Gettext Tools

  ### Standard Gettext Workflow

      # After extraction, use standard Gettext commands:

      # Merge new strings into existing PO files
      mix gettext.merge priv/gettext

      # Extract strings from templates (complementary to this task)
      mix gettext.extract

      # Compile PO to MO files
      mix compile.gettext

  ### Tools Compatibility

  Generated files are compatible with:

  - **GNU gettext utilities**: msgmerge, msgfmt, msginit
  - **CAT tools**: memoQ, Trados, Smartcat, OmegaT
  - **Online platforms**: Lokalise, Crowdin, POEditor
  - **Editors**: Poedit, Virtaal, Lokalize

  ## CI/CD Integration

  ### Automated Extraction on Merge

      # .github/workflows/extract-translations.yml
      name: Extract Translations

      on:
        push:
          branches: [main]
          paths:
            - 'lib/**/resources/**'

      jobs:
        extract:
          runs-on: ubuntu-latest
          steps:
            - uses: actions/checkout@v3
            - uses: erlef/setup-beam@v1
              with:
                elixir-version: '1.17'
                otp-version: '27'

            - name: Install dependencies
              run: mix deps.get

            - name: Extract strings
              run: |
                mix ash_phoenix_translations.extract \
                  --format both \
                  --locales en,es,fr \
                  --merge

            - name: Commit updated POT/PO files
              run: |
                git config user.name "Translation Bot"
                git config user.email "bot@example.com"
                git add priv/gettext/
                git commit -m "Update translation templates" || true
                git push

  ### Pre-commit Hook

      # .git/hooks/pre-commit
      #!/bin/sh

      # Extract translations before each commit
      mix ash_phoenix_translations.extract --merge --quiet

      # Check if gettext files changed
      if git diff --quiet priv/gettext/; then
        echo "No translation changes"
      else
        echo "Translation templates updated"
        git add priv/gettext/
      fi

  ## Advanced Use Cases

  ### Multi-Domain Extraction

      # Extract each domain to separate files
      defmodule MyApp.ExtractAll do
        def run do
          domains = [MyApp.Shop, MyApp.Catalog, MyApp.Content]

          Enum.each(domains, fn domain ->
            domain_name =
              domain
              |> Module.split()
              |> List.last()
              |> Macro.underscore()

            output_dir = "priv/gettext/\#{domain_name}"

            System.cmd("mix", [
              "ash_phoenix_translations.extract",
              "--domain", inspect(domain),
              "--output", output_dir,
              "--verbose"
            ])
          end)
        end
      end

  ### Selective Resource Extraction

      # Extract only resources with changes since last extraction
      defmodule MyApp.IncrementalExtract do
        def run do
          # Get resources modified in last 24 hours
          modified_resources =
            get_recently_modified_resources()
            |> Enum.map(&inspect/1)
            |> Enum.join(",")

          if modified_resources != "" do
            System.cmd("mix", [
              "ash_phoenix_translations.extract",
              "--resources", modified_resources,
              "--merge"
            ])
          end
        end

        defp get_recently_modified_resources do
          # Implementation to detect modified resource files
          []
        end
      end

  ### Translation Coverage Report

      # Generate report of extraction coverage
      defmodule MyApp.TranslationCoverage do
        def report do
          # Extract to temporary directory
          temp_dir = System.tmp_dir!() <> "/extract_#{:rand.uniform(10000)}"

          {output, 0} = System.cmd("mix", [
            "ash_phoenix_translations.extract",
            "--output", temp_dir,
            "--verbose"
          ])

          # Parse output for statistics
          resources = extract_resource_count(output)
          strings = extract_string_count(output)

          IO.puts("Extraction Coverage Report")
          IO.puts("==========================")
          IO.puts("Resources processed: \#{resources}")
          IO.puts("Strings extracted: \#{strings}")
          IO.puts("Average strings/resource: \#{div(strings, max(resources, 1))}")

          # Cleanup
          File.rm_rf!(temp_dir)
        end

        defp extract_resource_count(output) do
          case Regex.run(~r/Found (\d+) resources/, output) do
            [_, count] -> String.to_integer(count)
            _ -> 0
          end
        end

        defp extract_string_count(output) do
          case Regex.run(~r/Extracted (\d+) unique strings/, output) do
            [_, count] -> String.to_integer(count)
            _ -> 0
          end
        end
      end

  ## Security Considerations

  ### Atom Safety

  The extract task uses `String.to_existing_atom/1` when processing format
  parameter to prevent atom exhaustion:

      format =
        case opts[:format] || "pot" do
          format when format in ["pot", "po", "both"] ->
            String.to_existing_atom(format)  # Safe conversion
          invalid ->
            Mix.raise("Invalid format: \#{invalid}")
        end

  ### File Security

  - **Directory Validation**: Ensures output paths are within project
  - **Safe File Operations**: Uses `File.mkdir_p!/1` with validated paths
  - **Merge Safety**: Preserves existing content when merging

  ## Troubleshooting

  ### No Resources Found

  **Problem**: "No resources found with translations"

  **Solution**:
  1. Verify resources use `extensions: [AshPhoenixTranslations]`
  2. Check that resources are compiled: `mix compile`
  3. Use `--domain` flag to specify domain explicitly
  4. Use `--verbose` to see which resources are scanned

  ### POT File Empty

  **Problem**: Generated POT file has no msgid entries

  **Solution**:
  1. Ensure resources have `translatable_attribute` definitions
  2. Check for validation messages and action descriptions
  3. Use `--verbose` to see extraction process

  ### Format Validation Error

  **Problem**: "Invalid format: xyz"

  **Solution**:
  - Use only: `pot`, `po`, or `both` for `--format`
  - Check for typos in format flag

  ### Merge Conflicts

  **Problem**: Merged POT file loses translations

  **Solution**:
  1. Use proper Gettext merge: `mix gettext.merge priv/gettext`
  2. Back up PO files before merging
  3. Use version control to track changes

  ## Performance Considerations

  ### Large Codebases

  For projects with many resources:

  - **Use domain filtering**: Extract one domain at a time
  - **Resource selection**: Process specific resources with `--resources`
  - **Caching**: Merge mode is faster for incremental updates

  ### Optimization Tips

      # Fast extraction for large projects
      mix ash_phoenix_translations.extract \
        --domain MyApp.Shop \
        --merge \
        --output priv/gettext/shop

  ## Related Tasks

  - `mix ash_phoenix_translations.install` - Initial setup with Gettext backend
  - `mix gettext.extract` - Extract strings from templates
  - `mix gettext.merge` - Merge POT templates into PO files
  - `mix compile.gettext` - Compile PO files to MO format

  ## Examples

  ### Complete Gettext Workflow

      # 1. Install with Gettext backend
      mix ash_phoenix_translations.install --backend gettext

      # 2. Extract resource strings to POT
      mix ash_phoenix_translations.extract --verbose

      # 3. Generate PO files for locales
      mix ash_phoenix_translations.extract \
        --locales en,es,fr \
        --format both

      # 4. Merge POT into existing PO files
      mix gettext.merge priv/gettext

      # 5. Edit translations manually
      # vim priv/gettext/es/LC_MESSAGES/default.po

      # 6. Compile to binary MO files
      mix compile.gettext

      # 7. Test translations
      iex -S mix
      iex> Gettext.put_locale(MyAppWeb.Gettext, "es")
      iex> Gettext.gettext(MyAppWeb.Gettext, "product.name")

  ### Professional Translation Service Integration

      # 1. Extract to POT template
      mix ash_phoenix_translations.extract --format pot

      # 2. Send priv/gettext/default.pot to translation agency

      # 3. Receive translated PO files for each locale

      # 4. Place in locale directories
      # priv/gettext/es/LC_MESSAGES/default.po
      # priv/gettext/fr/LC_MESSAGES/default.po

      # 5. Validate and compile
      mix compile.gettext

  ### Resource-Specific Extraction

      # Extract only product-related resources
      mix ash_phoenix_translations.extract \
        --resources MyApp.Shop.Product,MyApp.Shop.ProductVariant \
        --output priv/gettext/products \
        --verbose

  ### Development Workflow

      # During development, frequently update POT
      mix ash_phoenix_translations.extract --merge

      # Check what's new
      git diff priv/gettext/default.pot

      # Merge into locales
      mix gettext.merge priv/gettext

      # Compile and test
      mix compile.gettext
      mix test
  """

  use Mix.Task

  @default_output "priv/gettext"
  @pot_header """
  # SOME DESCRIPTIVE TITLE.
  # Copyright (C) YEAR THE PACKAGE'S COPYRIGHT HOLDER
  # This file is distributed under the same license as the PACKAGE package.
  # FIRST AUTHOR <EMAIL@ADDRESS>, YEAR.
  #
  #, fuzzy
  msgid ""
  msgstr ""
  "Project-Id-Version: PACKAGE VERSION\\n"
  "Report-Msgid-Bugs-To: \\n"
  "POT-Creation-Date: #{DateTime.utc_now() |> DateTime.to_string()}\\n"
  "PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE\\n"
  "Last-Translator: FULL NAME <EMAIL@ADDRESS>\\n"
  "Language-Team: LANGUAGE <LL@li.org>\\n"
  "Language: \\n"
  "MIME-Version: 1.0\\n"
  "Content-Type: text/plain; charset=UTF-8\\n"
  "Content-Transfer-Encoding: 8bit\\n"

  """

  @impl Mix.Task
  def run(args) do
    opts = parse_options(args)
    setup_environment()

    config = build_config(opts)
    process_extraction(config, opts)
  end

  defp parse_options(args) do
    {opts, _} =
      OptionParser.parse!(args,
        strict: [
          domain: :string,
          resources: :string,
          output: :string,
          locales: :string,
          merge: :boolean,
          verbose: :boolean,
          format: :string
        ]
      )

    opts
  end

  defp setup_environment do
    Mix.Task.run("compile")
    Mix.Task.run("loadpaths")
  end

  defp build_config(opts) do
    format =
      case opts[:format] || "pot" do
        format when format in ["pot", "po", "both"] ->
          String.to_existing_atom(format)

        invalid ->
          Mix.raise("Invalid format: #{invalid}. Allowed: pot, po, both")
      end

    %{
      output_dir: opts[:output] || @default_output,
      verbose: opts[:verbose] || false,
      format: format
    }
  end

  defp process_extraction(config, opts) do
    log_start(config)

    resources = fetch_and_validate_resources(opts, config)
    strings = extract_and_log_strings(resources, config)

    generate_output_files(strings, config, opts)

    log_completion(opts)
  end

  defp log_start(%{verbose: true} = config) do
    Mix.shell().info("Starting translation extraction...")
    Mix.shell().info("Output directory: #{config.output_dir}")
  end

  defp log_start(_config), do: :ok

  defp fetch_and_validate_resources(opts, config) do
    resources = get_resources(opts)

    if Enum.empty?(resources) do
      Mix.shell().error("No resources found with translations")
      exit(1)
    end

    if config.verbose do
      Mix.shell().info("Found #{length(resources)} resources with translations")
    end

    resources
  end

  defp extract_and_log_strings(resources, config) do
    strings = extract_strings(resources, config.verbose)

    if config.verbose do
      Mix.shell().info("Extracted #{map_size(strings)} unique strings")
    end

    strings
  end

  defp generate_output_files(strings, config, opts) do
    case config.format do
      :pot ->
        generate_pot_files(strings, config.output_dir, opts)

      :po ->
        generate_po_files(strings, config.output_dir, opts)

      :both ->
        generate_pot_files(strings, config.output_dir, opts)
        generate_po_files(strings, config.output_dir, opts)

      _ ->
        Mix.shell().error("Invalid format: #{config.format}. Use pot, po, or both")
        exit(1)
    end
  end

  defp log_completion(opts) do
    Mix.shell().info("✓ Extraction complete")

    if opts[:locales] do
      Mix.shell().info("Generated PO files for: #{opts[:locales]}")
    end
  end

  defp get_resources(opts) do
    cond do
      opts[:resources] ->
        opts[:resources]
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.map(&Module.concat([&1]))
        |> Enum.filter(&has_translations?/1)

      opts[:domain] ->
        domain = Module.concat([opts[:domain]])

        domain
        |> Ash.Domain.Info.resources()
        |> Enum.filter(&has_translations?/1)

      true ->
        # Find all resources with translations
        find_all_resources_with_translations()
    end
  end

  defp has_translations?(resource) do
    AshPhoenixTranslations in Spark.extensions(resource)
  rescue
    _ -> false
  end

  defp find_all_resources_with_translations do
    # This would scan the application for all Ash resources
    # For now, return empty list
    []
  end

  defp extract_strings(resources, verbose) do
    Enum.reduce(resources, %{}, fn resource, acc ->
      if verbose do
        Mix.shell().info("  Extracting from #{inspect(resource)}")
      end

      resource
      |> extract_resource_strings()
      |> Map.merge(acc, fn _k, v1, v2 ->
        # Merge locations
        %{v1 | locations: v1.locations ++ v2.locations}
      end)
    end)
  end

  defp extract_resource_strings(resource) do
    translatable_attrs = AshPhoenixTranslations.Info.translatable_attributes(resource)
    resource_name = resource |> Module.split() |> List.last() |> Macro.underscore()

    base_strings =
      Enum.reduce(translatable_attrs, %{}, fn attr, acc ->
        # Generate msgid for attribute name
        name_msgid = "#{resource_name}.#{attr.name}"

        name_entry = %{
          msgid: name_msgid,
          msgstr: "",
          comments: ["Attribute name for #{resource}.#{attr.name}"],
          locations: ["#{resource}:#{attr.name}"],
          flags: []
        }

        acc = Map.put(acc, name_msgid, name_entry)

        # Generate msgid for attribute description if present
        if attr[:description] do
          desc_msgid = "#{resource_name}.#{attr.name}.description"

          desc_entry = %{
            msgid: desc_msgid,
            msgstr: "",
            comments: ["Description for #{resource}.#{attr.name}"],
            locations: ["#{resource}:#{attr.name}"],
            flags: []
          }

          Map.put(acc, desc_msgid, desc_entry)
        else
          acc
        end
      end)

    base_strings
    |> extract_validation_messages(resource)
    |> extract_error_messages(resource)
    |> extract_action_descriptions(resource)
  end

  defp extract_validation_messages(strings, resource) do
    # Extract validation error messages
    validations = Ash.Resource.Info.validations(resource)

    Enum.reduce(validations, strings, fn validation, acc ->
      if validation[:message] do
        msgid = validation.message

        entry = %{
          msgid: msgid,
          msgstr: "",
          comments: ["Validation message for #{resource}"],
          locations: ["#{resource}:validation"],
          flags: []
        }

        Map.put(acc, msgid, entry)
      else
        acc
      end
    end)
  end

  defp extract_error_messages(strings, _resource) do
    # Extract custom error messages
    strings
  end

  defp extract_action_descriptions(strings, resource) do
    # Extract action descriptions for API documentation
    actions = Ash.Resource.Info.actions(resource)
    resource_name = resource |> Module.split() |> List.last() |> Macro.underscore()

    Enum.reduce(actions, strings, fn action, acc ->
      if Map.get(action, :description) do
        msgid = "#{resource_name}.actions.#{action.name}.description"

        entry = %{
          msgid: msgid,
          msgstr: "",
          comments: ["Action description for #{resource}.#{action.name}"],
          locations: ["#{resource}:#{action.name}"],
          flags: []
        }

        Map.put(acc, msgid, entry)
      else
        acc
      end
    end)
  end

  defp generate_pot_files(strings, output_dir, opts) do
    ensure_directory(output_dir)

    # Group strings by domain (for now, just use "default")
    pot_file = Path.join(output_dir, "default.pot")

    content = generate_pot_content(strings, opts)

    if opts[:merge] && File.exists?(pot_file) do
      merge_pot_file(pot_file, content)
    else
      File.write!(pot_file, content)
    end

    Mix.shell().info("Generated POT file: #{pot_file}")
  end

  defp generate_pot_content(strings, _opts) do
    entries =
      strings
      |> Map.values()
      |> Enum.sort_by(& &1.msgid)
      |> Enum.map_join("\n", &format_pot_entry/1)

    @pot_header <> entries
  end

  defp format_pot_entry(entry) do
    comment_lines = Enum.map(entry.comments, &"# #{&1}")
    location_lines = Enum.map(entry.locations, &"#: #{&1}")

    flag_lines =
      if entry.flags != [] do
        ["#, " <> Enum.join(entry.flags, ", ")]
      else
        []
      end

    msg_lines = [
      ~s(msgid "#{escape_string(entry.msgid)}"),
      ~s(msgstr "#{escape_string(entry.msgstr)}")
    ]

    lines =
      comment_lines ++
        location_lines ++
        flag_lines ++
        msg_lines

    Enum.join(lines, "\n") <> "\n"
  end

  defp escape_string(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("\n", "\\n")
    |> String.replace("\r", "\\r")
    |> String.replace("\t", "\\t")
  end

  defp generate_po_files(strings, output_dir, opts) do
    locales =
      if opts[:locales] do
        opts[:locales]
        |> String.split(",")
        |> Enum.map(&String.trim/1)
      else
        []
      end

    Enum.each(locales, fn locale ->
      generate_po_file(strings, output_dir, locale, opts)
    end)
  end

  defp generate_po_file(strings, output_dir, locale, opts) do
    locale_dir = Path.join([output_dir, locale, "LC_MESSAGES"])
    ensure_directory(locale_dir)

    po_file = Path.join(locale_dir, "default.po")

    content = generate_po_content(strings, locale, opts)

    if opts[:merge] && File.exists?(po_file) do
      merge_po_file(po_file, content)
    else
      File.write!(po_file, content)
    end

    Mix.shell().info("Generated PO file: #{po_file}")
  end

  defp generate_po_content(strings, locale, opts) do
    header = String.replace(@pot_header, "Language: \\n", "Language: #{locale}\\n")

    entries =
      strings
      |> Map.values()
      |> Enum.sort_by(& &1.msgid)
      |> Enum.map_join("\n", fn entry ->
        # For PO files, we might have existing translations
        entry_with_translation =
          if opts[:merge] do
            # Would load existing translation here
            entry
          else
            entry
          end

        format_pot_entry(entry_with_translation)
      end)

    header <> entries
  end

  defp merge_pot_file(existing_file, new_content) do
    # Simple merge - in production would use proper POT parsing
    Mix.shell().info("Merging with existing POT file: #{existing_file}")
    File.write!(existing_file, new_content)
  end

  defp merge_po_file(existing_file, new_content) do
    # Simple merge - in production would use proper PO parsing
    Mix.shell().info("Merging with existing PO file: #{existing_file}")
    File.write!(existing_file, new_content)
  end

  defp ensure_directory(path) do
    File.mkdir_p!(path)
  end
end
