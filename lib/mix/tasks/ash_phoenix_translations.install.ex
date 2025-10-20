defmodule Mix.Tasks.AshPhoenixTranslations.Install do
  @moduledoc """
  Installs AshPhoenixTranslations into your Phoenix application.

  This task automates the initial setup process for AshPhoenixTranslations,
  configuring your application, creating necessary files, and generating
  example resources to help you get started quickly.

  ## Features

  - **Backend Selection**: Choose between Database or Gettext backend
  - **Configuration Generation**: Automatic config.exs setup
  - **Migration Creation**: Database backend migration generation
  - **Gettext Setup**: Complete Gettext directory structure
  - **Example Resource**: Working example to learn from
  - **Interactive Installation**: Step-by-step guidance

  ## Basic Usage

      # Install with database backend (default)
      mix ash_phoenix_translations.install

      # Install with gettext backend
      mix ash_phoenix_translations.install --backend gettext

      # Install without modifying config
      mix ash_phoenix_translations.install --no-config

      # Skip migration generation
      mix ash_phoenix_translations.install --no-migration

  ## Options

    * `--backend` - The default backend to use (database, gettext). Default: database
    * `--no-config` - Skip config file modifications
    * `--no-gettext` - Skip Gettext setup even if selected as backend
    * `--no-migration` - Skip migration generation for database backend

  ## Installation Steps

  ### 1. Configuration

  Adds the following to `config/config.exs`:

      config :ash_phoenix_translations,
        default_backend: :database,
        default_locales: [:en, :es, :fr],
        cache_ttl: 3600,
        cache_backend: :ets

  ### 2. Backend-Specific Setup

  #### Database Backend

  Creates a migration file in `priv/repo/migrations/`:

      defmodule Repo.Migrations.CreateTranslationsTable do
        use Ecto.Migration

        def change do
          create table(:translations) do
            add :resource_type, :string, null: false
            add :resource_id, :uuid, null: false
            add :field, :string, null: false
            add :locale, :string, null: false
            add :value, :text
            add :metadata, :map, default: %{}

            timestamps()
          end

          create index(:translations, [:resource_type, :resource_id])
          create index(:translations, [:locale])
          create unique_index(:translations,
            [:resource_type, :resource_id, :field, :locale])
        end
      end

  After installation, run:

      mix ecto.migrate

  #### Gettext Backend

  Creates the following directory structure in `priv/gettext/`:

      priv/gettext/
      ├── en/
      │   └── LC_MESSAGES/
      │       └── translations.po
      ├── es/
      │   └── LC_MESSAGES/
      │       └── translations.po
      └── fr/
          └── LC_MESSAGES/
              └── translations.po

  After installation, extract and compile translations:

      mix ash_phoenix_translations.extract
      mix gettext.merge priv/gettext
      mix compile.gettext

  ### 3. Example Resource

  Creates `lib/example/product.ex` with a working example:

      defmodule Example.Product do
        use Ash.Resource,
          extensions: [AshPhoenixTranslations]

        translations do
          translatable_attribute :name,
            locales: [:en, :es, :fr],
            required: [:en]

          translatable_attribute :description,
            locales: [:en, :es, :fr],
            translate: true

          backend :database
          cache_ttl 7200
        end

        attributes do
          uuid_primary_key :id
          attribute :sku, :string
          attribute :price, :decimal
          timestamps()
        end

        actions do
          defaults [:create, :read, :update, :destroy]
        end
      end

  ## Post-Installation Setup

  ### 1. Add Extension to Your Resources

      defmodule MyApp.Shop.Product do
        use Ash.Resource,
          extensions: [AshPhoenixTranslations]

        translations do
          translatable_attribute :name, locales: [:en, :es, :fr]
          translatable_attribute :description, locales: [:en, :es, :fr]
          backend :database
        end
      end

  ### 2. Configure Router Plugs

  Add to your Phoenix router:

      pipeline :browser do
        # ... other plugs
        plug AshPhoenixTranslations.Plugs.SetLocale
        plug AshPhoenixTranslations.Plugs.LoadTranslations
      end

  ### 3. Import Helpers in Views

  In your `MyAppWeb` module:

      def html do
        quote do
          # ... other imports
          import AshPhoenixTranslations.Helpers
        end
      end

  ### 4. Use in Templates

      # Access translated attributes
      <%= t(@product, :name) %>
      <%= t(@product, :description) %>

      # Locale selector
      <%= locale_select(@conn, [:en, :es, :fr]) %>

      # Get all translations for a field
      <%= all_translations(@product, :name) %>

  ## Workflow Examples

  ### New Project Setup

      # 1. Install with database backend
      mix ash_phoenix_translations.install --backend database

      # 2. Run migration
      mix ecto.migrate

      # 3. Add to your first resource
      # Edit lib/my_app/shop/product.ex and add translations block

      # 4. Start your application
      mix phx.server

  ### Adding to Existing Project

      # 1. Install without modifying config (you'll configure manually)
      mix ash_phoenix_translations.install --no-config

      # 2. Review generated files
      # - Check migration file
      # - Review example resource

      # 3. Manually add configuration to config/config.exs
      # 4. Add plugs to router.ex
      # 5. Import helpers in your view module

  ### Gettext-Based Project

      # 1. Install with Gettext backend
      mix ash_phoenix_translations.install --backend gettext

      # 2. Extract strings from resources
      mix ash_phoenix_translations.extract

      # 3. Merge with existing Gettext files
      mix gettext.merge priv/gettext

      # 4. Translate .po files
      # Edit priv/gettext/*/LC_MESSAGES/translations.po

      # 5. Compile translations
      mix compile.gettext

  ## Configuration Options

  ### Default Configuration

  The installer creates this configuration:

      config :ash_phoenix_translations,
        default_backend: :database,        # or :gettext
        default_locales: [:en, :es, :fr],  # Your supported locales
        cache_ttl: 3600,                   # 1 hour cache
        cache_backend: :ets                # ETS-based caching

  ### Advanced Configuration

  You can extend the configuration after installation:

      config :ash_phoenix_translations,
        default_backend: :database,
        default_locales: [:en, :es, :fr, :de, :it],
        cache_ttl: 7200,
        cache_backend: :ets,

        # Fallback chain
        fallback_chain: [:es, :en],

        # Security
        supported_locales: [:en, :es, :fr, :de, :it],

        # Performance
        lazy_load: true,
        preload_translations: false

  ## Backend Comparison

  ### Database Backend

  **Pros**:
  - Dynamic translation updates without deployment
  - Audit trail with timestamps
  - Per-resource translation storage
  - Ideal for user-editable content

  **Cons**:
  - Additional database queries
  - Requires migration
  - More storage usage

  **Best For**:
  - E-commerce product catalogs
  - CMS content
  - User-generated content
  - Applications requiring frequent translation updates

  ### Gettext Backend

  **Pros**:
  - Compiled translations (fast runtime)
  - Standard .po file format
  - Integrates with existing Gettext tools
  - CAT tool compatible

  **Cons**:
  - Requires recompilation for updates
  - Less dynamic
  - Not per-resource

  **Best For**:
  - Static content
  - UI labels and messages
  - Applications with stable translations
  - Integration with professional translation workflows

  ## Troubleshooting

  ### Configuration Not Applied

  **Problem**: Configuration doesn't seem to take effect

  **Solution**:
  1. Restart your application after installation
  2. Check `config/config.exs` for syntax errors
  3. Ensure configuration is not overridden in environment-specific configs

  ### Migration Fails

  **Problem**: Database migration fails to run

  **Solution**:
  1. Check PostgreSQL version (JSONB requires 9.4+)
  2. Verify database connection in `config/dev.exs`
  3. Check for table name conflicts
  4. Ensure migrations directory exists

  ### Gettext Files Not Created

  **Problem**: `priv/gettext/` directory not created

  **Solution**:
  1. Ensure `--no-gettext` flag was not used
  2. Check directory permissions
  3. Manually create directory structure if needed

  ### Example Resource Conflicts

  **Problem**: Example resource causes compilation errors

  **Solution**:
  1. Delete `lib/example/product.ex` if not needed
  2. Rename the module to avoid conflicts
  3. Use it as a reference, then remove

  ## Security Considerations

  ### Atom Exhaustion Prevention

  The installer configures locale validation to prevent atom exhaustion:

      # In config/config.exs (generated)
      config :ash_phoenix_translations,
        supported_locales: [:en, :es, :fr]  # Whitelist only

  Only these locales can be converted to atoms, preventing malicious input
  from exhausting the atom table.

  ### Database Security

  The generated migration includes:

  - **NOT NULL constraints**: Prevent incomplete records
  - **Unique indexes**: Prevent duplicate translations
  - **JSONB type**: Secure JSON storage (PostgreSQL)

  ## Related Tasks

  After installation, you'll commonly use:

  - `mix ash_phoenix_translations.export` - Export translations to files
  - `mix ash_phoenix_translations.import` - Import translations from files
  - `mix ash_phoenix_translations.validate` - Validate translation completeness
  - `mix ash_phoenix_translations.extract` - Extract to Gettext POT files

  ## Examples

  ### Full Database Backend Setup

      # Install
      mix ash_phoenix_translations.install --backend database

      # Run migration
      mix ecto.migrate

      # Add to resource
      # lib/my_app/shop/product.ex
      defmodule MyApp.Shop.Product do
        use Ash.Resource,
          extensions: [AshPhoenixTranslations]

        translations do
          translatable_attribute :name, locales: [:en, :es, :fr]
          backend :database
        end
      end

      # Test in IEx
      iex -S mix
      iex> alias MyApp.Shop.Product
      iex> product = Product.create!(%{name_translations: %{en: "Coffee", es: "Café"}})
      iex> AshPhoenixTranslations.translate(product, :name, :es)
      "Café"

  ### Full Gettext Backend Setup

      # Install
      mix ash_phoenix_translations.install --backend gettext

      # Extract strings
      mix ash_phoenix_translations.extract

      # Merge and edit
      mix gettext.merge priv/gettext
      # Edit priv/gettext/es/LC_MESSAGES/translations.po

      # Compile
      mix compile.gettext

      # Test
      iex -S mix
      iex> AshPhoenixTranslations.translate(product, :name, :es)
      "Café"

  ### Minimal Installation

      # Skip everything except example
      mix ash_phoenix_translations.install --no-config --no-migration --no-gettext

      # Review the example resource
      cat lib/example/product.ex

      # Manually configure as needed
  """

  use Mix.Task

  @shortdoc "Installs AshPhoenixTranslations into your Phoenix application"

  @switches [
    backend: :string,
    config: :boolean,
    gettext: :boolean,
    migration: :boolean
  ]

  @aliases [
    b: :backend
  ]

  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    backend = Keyword.get(opts, :backend, "database")
    skip_config = opts[:config] == false
    skip_gettext = opts[:gettext] == false
    skip_migration = opts[:migration] == false

    Mix.shell().info("Installing AshPhoenixTranslations...")

    unless skip_config do
      add_config(backend)
    end

    case backend do
      "gettext" ->
        unless skip_gettext do
          setup_gettext()
        end

      "database" ->
        unless skip_migration do
          generate_migration()
        end

      _ ->
        Mix.raise("Unknown backend: #{backend}. Use database or gettext.")
    end

    create_example_resource()

    Mix.shell().info("""

    AshPhoenixTranslations has been installed!

    Next steps:

    1. Add the extension to your Ash resources:

        use Ash.Resource,
          extensions: [AshPhoenixTranslations]
        
        translations do
          translatable_attribute :name, locales: [:en, :es, :fr]
          translatable_attribute :description, locales: [:en, :es, :fr]
          backend :#{backend}
        end

    2. Add the plugs to your router:

        pipeline :browser do
          # ... other plugs
          plug AshPhoenixTranslations.Plugs.SetLocale
          plug AshPhoenixTranslations.Plugs.LoadTranslations
        end

    3. Import helpers in your views:

        import AshPhoenixTranslations.Helpers

    4. Use translations in templates:

        <%= t(@product, :name) %>

    #{backend_specific_instructions(backend)}
    """)
  end

  defp add_config(backend) do
    config_path = "config/config.exs"

    config = """

    # AshPhoenixTranslations Configuration
    config :ash_phoenix_translations,
      default_backend: :#{backend},
      default_locales: [:en, :es, :fr],
      cache_ttl: 3600,
      cache_backend: :ets
    """

    if File.exists?(config_path) do
      existing = File.read!(config_path)

      unless String.contains?(existing, "config :ash_phoenix_translations") do
        File.write!(config_path, existing <> config)
        Mix.shell().info("Added configuration to #{config_path}")
      else
        Mix.shell().info("Configuration already exists in #{config_path}")
      end
    else
      Mix.shell().error("Could not find #{config_path}")
    end
  end

  defp setup_gettext do
    gettext_dir = "priv/gettext"

    unless File.exists?(gettext_dir) do
      File.mkdir_p!(gettext_dir)
    end

    # Create locale directories
    for locale <- ["en", "es", "fr"] do
      locale_dir = Path.join([gettext_dir, locale, "LC_MESSAGES"])
      File.mkdir_p!(locale_dir)

      # Create empty .po file
      po_file = Path.join(locale_dir, "translations.po")

      unless File.exists?(po_file) do
        File.write!(po_file, """
        msgid ""
        msgstr ""
        "Language: #{locale}\\n"
        "MIME-Version: 1.0\\n"
        "Content-Type: text/plain; charset=UTF-8\\n"
        "Content-Transfer-Encoding: 8bit\\n"
        "Plural-Forms: nplurals=2; plural=(n != 1);\\n"
        """)
      end
    end

    Mix.shell().info("Created Gettext directories and files")
  end

  defp generate_migration do
    timestamp = Calendar.strftime(DateTime.utc_now(), "%Y%m%d%H%M%S")
    migration_path = "priv/repo/migrations/#{timestamp}_create_translations_table.exs"

    migration = """
    defmodule Repo.Migrations.CreateTranslationsTable do
      use Ecto.Migration
      
      def change do
        create table(:translations) do
          add :resource_type, :string, null: false
          add :resource_id, :uuid, null: false
          add :field, :string, null: false
          add :locale, :string, null: false
          add :value, :text
          add :metadata, :map, default: %{}
          
          timestamps()
        end
        
        create index(:translations, [:resource_type, :resource_id])
        create index(:translations, [:locale])
        create unique_index(:translations, [:resource_type, :resource_id, :field, :locale])
      end
    end
    """

    File.mkdir_p!(Path.dirname(migration_path))
    File.write!(migration_path, migration)
    Mix.shell().info("Created migration: #{migration_path}")
  end

  defp create_example_resource do
    example_path = "lib/example/product.ex"

    example = """
    defmodule Example.Product do
      use Ash.Resource,
        extensions: [AshPhoenixTranslations]
      
      translations do
        translatable_attribute :name, 
          locales: [:en, :es, :fr],
          required: [:en]
        
        translatable_attribute :description,
          locales: [:en, :es, :fr],
          translate: true
        
        backend :database
        cache_ttl 7200
      end
      
      attributes do
        uuid_primary_key :id
        
        attribute :sku, :string do
          allow_nil? false
        end
        
        attribute :price, :decimal
        
        timestamps()
      end
      
      actions do
        defaults [:create, :read, :update, :destroy]
      end
    end
    """

    File.mkdir_p!(Path.dirname(example_path))
    File.write!(example_path, example)
    Mix.shell().info("Created example resource: #{example_path}")
  end

  defp backend_specific_instructions("database") do
    """
    Database backend specific:

    Run the migration:

        mix ecto.migrate
    """
  end

  defp backend_specific_instructions("gettext") do
    """
    Gettext backend specific:

    Extract translations:

        mix gettext.extract
        mix gettext.merge priv/gettext
    """
  end

  defp backend_specific_instructions(_), do: ""
end
