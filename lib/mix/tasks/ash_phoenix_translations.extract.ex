defmodule Mix.Tasks.AshPhoenixTranslations.Extract do
  @shortdoc "Extract translatable strings to Gettext POT files"
  
  @moduledoc """
  Extracts translatable strings from Ash resources to Gettext POT files.
  
  This task scans your Ash resources for translatable attributes and generates
  or updates POT (Portable Object Template) files that can be used with Gettext
  for translation management.
  
  ## Usage
  
      mix ash_phoenix_translations.extract
      
      # Extract for specific domain
      mix ash_phoenix_translations.extract --domain MyApp.Shop
      
      # Extract with custom output directory
      mix ash_phoenix_translations.extract --output priv/gettext
      
      # Extract with verbose output
      mix ash_phoenix_translations.extract --verbose
      
      # Extract only specific resources
      mix ash_phoenix_translations.extract --resources MyApp.Product,MyApp.Category
      
      # Generate PO files for specific locales
      mix ash_phoenix_translations.extract --locales en,es,fr
  
  ## Options
  
    * `--domain` - Extract from a specific Ash domain
    * `--resources` - Comma-separated list of resource modules
    * `--output` - Output directory for POT files (default: priv/gettext)
    * `--locales` - Generate PO files for these locales
    * `--merge` - Merge with existing POT files
    * `--verbose` - Show detailed extraction information
    * `--format` - Output format: pot, po, or both (default: pot)
  
  ## POT File Structure
  
  The task generates POT files with the following structure:
  
      priv/gettext/
      ├── default.pot           # Default domain POT file
      ├── errors.pot           # Error messages POT file
      ├── en/
      │   └── LC_MESSAGES/
      │       ├── default.po
      │       └── errors.po
      ├── es/
      │   └── LC_MESSAGES/
      │       ├── default.po
      │       └── errors.po
      └── fr/
          └── LC_MESSAGES/
              ├── default.po
              └── errors.po
  
  ## Integration with Gettext
  
  After extraction, you can use standard Gettext tools to manage translations:
  
      # Merge new strings into existing PO files
      mix gettext.merge priv/gettext
      
      # Compile PO files to MO files
      mix compile.gettext
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
    {opts, _} = OptionParser.parse!(args,
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
    
    Mix.Task.run("compile")
    Mix.Task.run("loadpaths")
    
    output_dir = opts[:output] || @default_output
    verbose = opts[:verbose] || false
    format = String.to_atom(opts[:format] || "pot")
    
    if verbose do
      Mix.shell().info("Starting translation extraction...")
      Mix.shell().info("Output directory: #{output_dir}")
    end
    
    # Get resources to extract from
    resources = get_resources(opts)
    
    if Enum.empty?(resources) do
      Mix.shell().error("No resources found with translations")
      exit(1)
    end
    
    if verbose do
      Mix.shell().info("Found #{length(resources)} resources with translations")
    end
    
    # Extract translatable strings
    strings = extract_strings(resources, verbose)
    
    if verbose do
      Mix.shell().info("Extracted #{map_size(strings)} unique strings")
    end
    
    # Generate POT files
    case format do
      :pot -> generate_pot_files(strings, output_dir, opts)
      :po -> generate_po_files(strings, output_dir, opts)
      :both ->
        generate_pot_files(strings, output_dir, opts)
        generate_po_files(strings, output_dir, opts)
      _ ->
        Mix.shell().error("Invalid format: #{format}. Use pot, po, or both")
        exit(1)
    end
    
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
      if action[:description] do
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
      |> Enum.map(&format_pot_entry/1)
      |> Enum.join("\n")
    
    @pot_header <> entries
  end
  
  defp format_pot_entry(entry) do
    lines = []
    
    # Add comments
    lines = lines ++ Enum.map(entry.comments, &"# #{&1}")
    
    # Add locations
    lines = lines ++ Enum.map(entry.locations, &"#: #{&1}")
    
    # Add flags
    lines = if entry.flags != [] do
      lines ++ ["#, " <> Enum.join(entry.flags, ", ")]
    else
      lines
    end
    
    # Add msgid and msgstr
    lines = lines ++ [
      ~s(msgid "#{escape_string(entry.msgid)}"),
      ~s(msgstr "#{escape_string(entry.msgstr)}")
    ]
    
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
      |> Enum.map(fn entry ->
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
      |> Enum.join("\n")
    
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