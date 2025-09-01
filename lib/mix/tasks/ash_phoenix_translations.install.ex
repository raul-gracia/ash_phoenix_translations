defmodule Mix.Tasks.AshPhoenixTranslations.Install do
  @moduledoc """
  Installs AshPhoenixTranslations into your Phoenix application.

  ## Usage

      mix ash_phoenix_translations.install
      
  ## Options

    * `--backend` - The default backend to use (database, gettext). Default: database
    * `--no-config` - Skip config file modifications
    * `--no-gettext` - Skip Gettext setup even if selected as backend
    * `--no-migration` - Skip migration generation for database backend

  ## What it does

  1. Adds configuration to config/config.exs
  2. Generates Gettext modules if using gettext backend
  3. Creates migration for database backend
  4. Adds required dependencies to mix.exs
  5. Creates example resource with translations
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
