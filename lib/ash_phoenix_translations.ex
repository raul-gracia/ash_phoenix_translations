defmodule AshPhoenixTranslations do
  @moduledoc """
  AshPhoenixTranslations - A powerful Ash Framework extension for handling translations
  in Phoenix applications with policy-aware, multi-backend support.

  This extension provides a complete translation solution for Ash resources, including:
  - Multiple storage backends (Database JSONB, Gettext .po files, Redis)
  - Policy-based access control for viewing and editing translations
  - ETS-based caching with TTL support
  - LiveView integration with reactive locale switching
  - Audit trail for translation changes
  - Automatic validation and fallback handling
  - Import/export tools for translation workflows

  ## Installation

  Add to your `mix.exs`:

      defp deps do
        [
          {:ash_phoenix_translations, "~> 1.0"}
        ]
      end

  Then run:

      mix deps.get
      mix ash_phoenix_translations.install --backend database

  ## Quick Start

  ### 1. Add Extension to Resource

      defmodule MyApp.Catalog.Product do
        use Ash.Resource,
          domain: MyApp.Catalog,
          data_layer: AshPostgres.DataLayer,
          extensions: [AshPhoenixTranslations]

        translations do
          # Define translatable attributes
          translatable_attribute :name, :string do
            locales [:en, :es, :fr, :de]
            required [:en]
          end

          translatable_attribute :description, :text do
            locales [:en, :es, :fr, :de]
            markdown true
          end

          # Choose storage backend
          backend :database

          # Enable caching (recommended)
          cache_ttl 3600

          # Track changes (optional)
          audit_changes true
        end

        # Define your other resource attributes
        attributes do
          uuid_primary_key :id
          attribute :sku, :string
          create_timestamp :created_at
          update_timestamp :updated_at
        end

        actions do
          defaults [:read, :create, :update, :destroy]
        end
      end

  ### 2. Configure Application

  In `config/config.exs`:

      config :ash_phoenix_translations,
        default_backend: :database,
        default_locales: [:en, :es, :fr, :de],
        default_locale: :en,
        cache_ttl: 3600,
        supported_locales: [:en, :es, :fr, :de, :it, :pt, :ja, :zh]

  ### 3. Add Router Plugs

  In `lib/my_app_web/router.ex`:

      pipeline :browser do
        plug :accepts, ["html"]
        plug :fetch_session
        plug :fetch_live_flash
        plug :put_root_layout, {MyAppWeb.LayoutView, :root}
        plug :protect_from_forgery
        plug :put_secure_browser_headers

        # Add translation plugs
        plug AshPhoenixTranslations.Plugs.SetLocale
        plug AshPhoenixTranslations.Plugs.LoadTranslations
      end

  ### 4. Use in Controllers

      defmodule MyAppWeb.ProductController do
        use MyAppWeb, :controller
        import AshPhoenixTranslations

        def show(conn, %{"id" => id}) do
          product =
            MyApp.Catalog.Product
            |> Ash.get!(id)
            |> translate(conn)  # Translates to current locale

          render(conn, "show.html", product: product)
        end

        def index(conn, _params) do
          products =
            MyApp.Catalog.Product
            |> Ash.read!()
            |> translate_all(conn)  # Translates all products

          render(conn, "index.html", products: products)
        end
      end

  ### 5. Use in LiveView

      defmodule MyAppWeb.ProductLive.Show do
        use MyAppWeb, :live_view
        import AshPhoenixTranslations

        def mount(%{"id" => id}, _session, socket) do
          product = MyApp.Catalog.Product |> Ash.get!(id)
          {translated_product, socket} = live_translate(product, socket)

          {:ok, assign(socket, product: translated_product)}
        end

        def handle_event("change_locale", %{"locale" => locale}, socket) do
          socket = update_locale(socket, String.to_existing_atom(locale))
          {:noreply, socket}
        end
      end

  ## DSL Reference

  The `translations do ... end` block accepts the following configuration:

  ### Backend Configuration

  #### `:backend` - Storage Backend

  Choose where translations are stored:
  - `:database` - Store in JSONB columns (PostgreSQL recommended)
  - `:gettext` - Integrate with Phoenix's Gettext system (.po files)
  - `:redis` - Store in Redis (for multi-server deployments)

  **Default:** `:database`

  **Examples:**

      # Database backend (most common)
      translations do
        backend :database
        translatable_attribute :name, :string, locales: [:en, :es, :fr]
      end

      # Gettext backend (integrate with existing .po files)
      translations do
        backend :gettext
        gettext_module MyAppWeb.Gettext
        translatable_attribute :name, :string, locales: [:en, :es, :fr]
      end

      # Redis backend (multi-server deployments)
      translations do
        backend :redis
        translatable_attribute :name, :string, locales: [:en, :es, :fr]
      end

  #### `:gettext_module` - Gettext Module

  Required when using `:gettext` backend. Specifies the Gettext module to use.

  **Example:**

      translations do
        backend :gettext
        gettext_module MyAppWeb.Gettext
        translatable_attribute :title, :string, locales: [:en, :es]
      end

  ### Caching Configuration

  #### `:cache_ttl` - Cache Time-to-Live

  How long to cache translations in seconds.

  **Default:** `3600` (1 hour)

  **Examples:**

      # Short cache for frequently changing content
      translations do
        cache_ttl 300  # 5 minutes
      end

      # Long cache for stable content
      translations do
        cache_ttl 86400  # 24 hours
      end

      # Disable caching (not recommended)
      translations do
        cache_ttl 0
      end

  ### Audit Configuration

  #### `:audit_changes` - Track Translation Changes

  Enable audit trail for all translation modifications.

  **Default:** `false`

  **Example:**

      translations do
        audit_changes true
        translatable_attribute :name, :string, locales: [:en, :es]
      end

  When enabled, creates `TranslationAudit` records tracking:
  - Which field was changed
  - Which locale was modified
  - Old and new values
  - Who made the change (actor from context)
  - When the change occurred

  #### `:auto_validate` - Automatic Validation

  Automatically validate required translations on create/update.

  **Default:** `true`

  **Example:**

      translations do
        auto_validate false  # Disable automatic validation
        translatable_attribute :name, :string do
          locales [:en, :es, :fr]
          required [:en]  # Still requires English
        end
      end

  ### Policy Configuration

  Control who can view and edit translations using role-based or custom policies.

  #### `:policy` - Access Control

  **Schema:**

      policy [
        view: :public | :authenticated | :admin | :translator | {Module, :function},
        edit: :admin | :translator | {Module, :function},
        approval: [
          approvers: [:admin, :manager],
          required_for: [:production]
        ]
      ]

  **Examples:**

      # Public read, admin write
      translations do
        policy view: :public, edit: :admin
      end

      # Authenticated users can view, translators can edit
      translations do
        policy view: :authenticated, edit: :translator
      end

      # Custom policy functions
      translations do
        policy view: {MyApp.Policies, :can_view_translations},
               edit: {MyApp.Policies, :can_edit_translations}
      end

      # Approval workflow
      translations do
        policy edit: :translator,
               approval: [
                 approvers: [:admin, :translation_manager],
                 required_for: [:production]
               ]
      end

  ### Translatable Attributes

  Define which attributes can be translated:

      translatable_attribute :field_name, :type do
        locales [:en, :es, :fr, ...]
        required [:en]
        markdown true
        fallback_locale :en
      end

  **Options:**

  - `:locales` - List of supported locales for this field (required)
  - `:required` - List of locales that must have values
  - `:markdown` - Enable markdown rendering (default: `false`)
  - `:fallback_locale` - Locale to use when translation is missing

  **Examples:**

      # Simple translatable string
      translatable_attribute :name, :string do
        locales [:en, :es, :fr]
        required [:en]
      end

      # Rich text with markdown
      translatable_attribute :description, :text do
        locales [:en, :es, :fr, :de]
        markdown true
        required [:en]
      end

      # Short tagline
      translatable_attribute :tagline, :string do
        locales [:en, :es, :fr]
        fallback_locale :en
      end

  ## Complete Example: Multi-Language Blog

      defmodule MyBlog.Content.Article do
        use Ash.Resource,
          domain: MyBlog.Content,
          data_layer: AshPostgres.DataLayer,
          extensions: [AshPhoenixTranslations]

        translations do
          # Article title - required in all languages
          translatable_attribute :title, :string do
            locales [:en, :es, :fr, :de, :it]
            required [:en, :es, :fr]  # Must have these 3
          end

          # Article content with markdown support
          translatable_attribute :content, :text do
            locales [:en, :es, :fr, :de, :it]
            markdown true
            required [:en]
          end

          # Meta description for SEO
          translatable_attribute :meta_description, :string do
            locales [:en, :es, :fr, :de, :it]
            fallback_locale :en
          end

          # Storage configuration
          backend :database
          cache_ttl 1800  # 30 minutes

          # Track who changed what
          audit_changes true

          # Access control
          policy view: :public,
                 edit: :translator,
                 approval: [
                   approvers: [:editor, :admin],
                   required_for: [:production]
                 ]
        end

        attributes do
          uuid_primary_key :id

          attribute :slug, :string do
            allow_nil? false
          end

          attribute :published, :boolean do
            default false
          end

          attribute :author_id, :uuid

          create_timestamp :created_at
          update_timestamp :updated_at
        end

        relationships do
          belongs_to :author, MyBlog.Accounts.User
        end

        actions do
          defaults [:read, :destroy]

          create :create do
            accept [:slug, :title_translations, :content_translations]

            change fn changeset, _context ->
              # Auto-generate slugs for all languages
              case Ash.Changeset.get_attribute(changeset, :title_translations) do
                nil -> changeset
                titles ->
                  slug_trans = Enum.map(titles, fn {locale, title} ->
                    {locale, Slug.slugify(title)}
                  end) |> Enum.into(%{})

                  Ash.Changeset.force_change_attribute(changeset, :slug_translations, slug_trans)
              end
            end
          end

          update :update do
            accept [:title_translations, :content_translations, :meta_description_translations, :published]
          end

          update :publish do
            accept []

            change fn changeset, _context ->
              Ash.Changeset.force_change_attribute(changeset, :published, true)
            end
          end
        end

        policies do
          # Anyone can read published articles
          policy action_type(:read) do
            authorize_if expr(published == true)
          end

          # Authors can manage their own articles
          policy action_type([:create, :update, :destroy]) do
            authorize_if expr(author_id == ^actor(:id))
          end

          # Editors can manage all articles
          policy action_type([:create, :update, :destroy]) do
            authorize_if actor_attribute_equals(:role, :editor)
          end
        end
      end

  ## Backend Comparison

  ### Database Backend (Recommended)

  **Pros:**
  - Single source of truth
  - Transactional safety
  - Efficient querying
  - Built-in indexing (JSONB GIN indexes)
  - Works out of the box

  **Cons:**
  - Requires PostgreSQL for JSONB
  - Database storage overhead

  **Best for:**
  - Most applications
  - Single-server deployments
  - When you need ACID guarantees

  **Example Schema:**

      CREATE TABLE products (
        id UUID PRIMARY KEY,
        sku VARCHAR(255),
        name_translations JSONB,        -- {"en": "Product", "es": "Producto"}
        description_translations JSONB,
        created_at TIMESTAMP
      );

      CREATE INDEX idx_products_name_translations
        ON products USING GIN (name_translations);

  ### Gettext Backend

  **Pros:**
  - Integrates with existing Phoenix/Gettext workflow
  - .po file format (standard translation format)
  - Easy to use with external translation services
  - Version control friendly

  **Cons:**
  - Requires compilation for changes
  - Less dynamic than database
  - Harder to query

  **Best for:**
  - Existing Phoenix apps using Gettext
  - Translation managed by external services
  - Static content that changes infrequently

  **Example Files:**

      # priv/gettext/en/LC_MESSAGES/product.po
      msgid "product_name_%{id}"
      msgstr "My Product"

      # priv/gettext/es/LC_MESSAGES/product.po
      msgid "product_name_%{id}"
      msgstr "Mi Producto"

  ### Redis Backend

  **Pros:**
  - Shared state across multiple servers
  - Fast in-memory access
  - Built-in TTL support
  - Pub/sub for cache invalidation

  **Cons:**
  - Additional infrastructure (Redis server)
  - Eventual consistency
  - More complex setup

  **Best for:**
  - Multi-server deployments
  - High-traffic applications
  - When you need cross-server cache invalidation

  **Example Configuration:**

      config :ash_phoenix_translations,
        backend: :redis,
        redis_url: "redis://localhost:6379/0",
        redis_pool_size: 10

  ## LiveView Integration

  ### Basic Setup

      defmodule MyAppWeb.ProductLive.Show do
        use MyAppWeb, :live_view
        import AshPhoenixTranslations

        def mount(%{"id" => id}, _session, socket) do
          product = MyApp.Catalog.Product |> Ash.get!(id)

          # Use live_translate for reactive updates
          {translated_product, socket} = live_translate(product, socket)

          {:ok, assign(socket, product: translated_product)}
        end

        def handle_event("switch_locale", %{"locale" => locale_str}, socket) do
          locale = String.to_existing_atom(locale_str)

          # Update locale and automatically retranslate
          socket = update_locale(socket, locale)

          {:noreply, socket}
        end
      end

  ### Translation Editor LiveView

      defmodule MyAppWeb.ProductLive.TranslationEditor do
        use MyAppWeb, :live_view
        import AshPhoenixTranslations

        def mount(%{"id" => id}, _session, socket) do
          product = MyApp.Catalog.Product |> Ash.get!(id)

          attrs = translatable_attributes(MyApp.Catalog.Product)

          socket =
            socket
            |> assign(:product, product)
            |> assign(:translatable_attrs, attrs)
            |> assign(:current_field, nil)
            |> assign(:current_locale, :en)
            |> calculate_completeness()

          {:ok, socket}
        end

        def handle_event("edit_translation", params, socket) do
          %{"field" => field, "locale" => locale, "value" => value} = params

          product = socket.assigns.product

          # Update translation
          updates = %{
            "\#{field}_translations" => Map.put(
              Map.get(product, String.to_existing_atom("\#{field}_translations")),
              String.to_existing_atom(locale),
              value
            )
          }

          case Ash.update(product, :update, updates) do
            {:ok, updated_product} ->
              socket =
                socket
                |> assign(:product, updated_product)
                |> calculate_completeness()
                |> put_flash(:info, "Translation updated")

              {:noreply, socket}

            {:error, error} ->
              {:noreply, put_flash(socket, :error, "Failed to update: \#{inspect(error)}")}
          end
        end

        defp calculate_completeness(socket) do
          product = socket.assigns.product
          completeness = translation_completeness(product)

          assign(socket, :completeness_percentage, completeness)
        end
      end

  ## Performance Optimization

  ### Caching Strategy

  The extension uses ETS-based caching with TTL support:

      # Configure globally
      config :ash_phoenix_translations,
        cache_ttl: 3600,           # 1 hour default
        cache_enabled: true

      # Or per resource
      translations do
        cache_ttl 1800  # 30 minutes
      end

  ### Cache Invalidation

  Caches are automatically invalidated when translations are updated.
  For manual invalidation:

      AshPhoenixTranslations.Cache.invalidate(resource, field, locale)
      AshPhoenixTranslations.Cache.clear()  # Clear all caches

  ### Database Indexes

  For database backend, add GIN indexes on JSONB columns:

      CREATE INDEX idx_products_name_translations
        ON products USING GIN (name_translations);

      CREATE INDEX idx_products_description_translations
        ON products USING GIN (description_translations);

  ## Security Considerations

  ### Atom Exhaustion Prevention

  The extension uses `String.to_existing_atom/1` to prevent atom exhaustion attacks:

      # Safe - only converts to existing atoms
      locale = String.to_existing_atom("en")  # ✓ Works if :en exists

      # Safe - validates against whitelist
      {:ok, locale} = AshPhoenixTranslations.LocaleValidator.validate_locale("en")

  ### Input Validation

  All user input is validated before being converted to atoms:

      # Locale validation
      config :ash_phoenix_translations,
        supported_locales: [:en, :es, :fr]  # Whitelist

      # Field validation uses existing resource fields only

  ### XSS Prevention

  When rendering translations:

      # In templates, always escape HTML
      <%= @product.name %>  # Automatically escaped by Phoenix

      # For markdown, use a sanitizer
      <%= raw(Earmark.as_html!(@product.description) |> HtmlSanitizeEx.basic_html()) %>

  ## Translation Workflows

  ### Export for Translation Service

      # Export missing Spanish translations
      mix ash_phoenix_translations.export missing_es.csv \
        --resource MyApp.Product \
        --locale es \
        --missing-only

  ### Import Completed Translations

      # Preview changes first
      mix ash_phoenix_translations.import translations.csv \
        --resource MyApp.Product \
        --dry-run

      # Apply changes
      mix ash_phoenix_translations.import translations.csv \
        --resource MyApp.Product

  ### Validate Completeness

      # Check translation completeness
      mix ash_phoenix_translations.validate \
        --resource MyApp.Product \
        --locale es \
        --strict

  ## Programmatic Examples

      # Load a product
      product = MyApp.Catalog.Product |> Ash.get!(id)

      # Translate to Spanish
      spanish_product = AshPhoenixTranslations.translate(product, :es)
      spanish_product.name
      # => "Producto Español"

      # Get specific translation
      name_es = AshPhoenixTranslations.translate_field(product, :name, :es)
      # => "Producto Español"

      # Check available locales
      locales = AshPhoenixTranslations.available_locales(product, :name)
      # => [:en, :es, :fr]

      # Calculate completeness
      completeness = AshPhoenixTranslations.translation_completeness(product)
      # => 75.0  (75% of translations are present)

      # Translate multiple resources
      products = MyApp.Catalog.Product |> Ash.read!()
      spanish_products = AshPhoenixTranslations.translate_all(products, :es)

  ## Migration from Other Solutions

  ### From Gettext-only

  If you're using Gettext directly in your app:

  1. Add the extension to your resources with `backend: :gettext`
  2. Keep your existing .po files
  3. Configure `gettext_module` option
  4. Update code to use `translate/2` instead of `Gettext.gettext/3`

  ### From Ecto-embedded Schemas

  If you're using embedded schemas for translations:

  1. Add the extension with `backend: :database`
  2. Migrate data from embedded schemas to JSONB columns
  3. Update queries to use the new structure
  4. Remove embedded schema definitions

  ## Troubleshooting

  ### Translations not appearing

  **Check:**
  1. Backend is configured correctly
  2. Storage fields exist (e.g., `name_translations`)
  3. Locale is set in conn/socket assigns
  4. Calculations are loaded (use `translate/2` helpers)

  ### Cache not invalidating

  **Solution:**
  - Ensure you're using the built-in update actions
  - Manually invalidate: `AshPhoenixTranslations.Cache.invalidate/3`

  ### Performance issues

  **Solutions:**
  1. Enable caching with appropriate TTL
  2. Add database indexes on JSONB columns
  3. Use Redis backend for multi-server deployments
  4. Lazy-load translations (don't load all locales at once)

  ## Additional Resources

  - [Full Documentation](https://hexdocs.pm/ash_phoenix_translations)
  - [GitHub Repository](https://github.com/yourusername/ash_phoenix_translations)
  - [Ash Framework Documentation](https://hexdocs.pm/ash)
  - [Phoenix Framework Documentation](https://hexdocs.pm/phoenix)

  """

  @transformers [
    AshPhoenixTranslations.Transformers.AddTranslationStorage,
    AshPhoenixTranslations.Transformers.AddTranslationRelationships,
    AshPhoenixTranslations.Transformers.AddTranslationActions,
    AshPhoenixTranslations.Transformers.AddTranslationCalculations,
    AshPhoenixTranslations.Transformers.AddTranslationChanges,
    AshPhoenixTranslations.Transformers.SetupTranslationPolicies
  ]

  use Spark.Dsl.Extension,
    transformers: @transformers,
    sections: [
      %Spark.Dsl.Section{
        name: :translations,
        describe: "Configure translation behavior for the resource",
        schema: [
          backend: [
            type: {:in, [:database, :gettext, :redis]},
            default: :database,
            doc: "The backend to use for storing translations (database, gettext, or redis)"
          ],
          gettext_module: [
            type: :atom,
            doc:
              "The Gettext module to use (e.g., MyAppWeb.Gettext). Required when backend is :gettext"
          ],
          cache_ttl: [
            type: :pos_integer,
            default: 3600,
            doc: "Cache TTL in seconds"
          ],
          audit_changes: [
            type: :boolean,
            default: false,
            doc: "Whether to audit translation changes"
          ],
          auto_validate: [
            type: :boolean,
            default: true,
            doc: "Whether to automatically validate required translations"
          ],
          policy: [
            type: :keyword_list,
            doc: "Policy configuration for translation access control",
            keys: [
              view: [
                type:
                  {:or,
                   [
                     {:in, [:public, :authenticated, :admin, :translator]},
                     {:tuple, [:atom, :keyword_list]},
                     :atom
                   ]},
                doc: "Policy for viewing translations"
              ],
              edit: [
                type:
                  {:or,
                   [
                     {:in, [:admin, :translator]},
                     {:tuple, [:atom, {:list, :atom}]},
                     :atom
                   ]},
                doc: "Policy for editing translations"
              ],
              approval: [
                type: :keyword_list,
                doc: "Approval workflow configuration",
                keys: [
                  approvers: [
                    type: {:list, :atom},
                    doc: "List of roles that can approve translations"
                  ],
                  required_for: [
                    type: {:list, :atom},
                    doc: "Environments where approval is required"
                  ]
                ]
              ]
            ]
          ]
        ],
        entities: [
          %Spark.Dsl.Entity{
            name: :translatable_attribute,
            describe: "Define a translatable attribute",
            args: [:name, :type],
            target: AshPhoenixTranslations.TranslatableAttribute,
            schema: AshPhoenixTranslations.TranslatableAttribute.schema(),
            transform: {AshPhoenixTranslations.TranslatableAttribute, :transform, []}
          }
        ]
      }
    ]

  @doc """
  Translate a single resource based on the connection's locale.

  This function loads calculated translation fields based on the current locale
  and returns a copy of the resource with the translated values. It automatically
  detects whether you're passing a `Plug.Conn`, `Phoenix.LiveView.Socket`, or
  an atom representing the locale.

  ## Parameters

  - `resource` - The Ash resource struct to translate
  - `conn_or_socket_or_locale` - One of:
    - `%Plug.Conn{}` - Uses `conn.assigns.locale` or session locale
    - `%Phoenix.LiveView.Socket{}` - Uses socket assigns or connect params
    - `:locale` - An atom representing the desired locale (e.g., `:es`, `:fr`)

  ## Return Value

  Returns a copy of the resource with calculated translation fields loaded
  for the specified locale. If a translation is missing, the fallback chain
  is applied (fallback_locale → default_locale → field name).

  ## Examples

      # In a Phoenix Controller
      def show(conn, %{"id" => id}) do
        product = MyApp.Catalog.Product |> Ash.get!(id)

        # Uses locale from conn.assigns.locale or session
        translated = AshPhoenixTranslations.translate(product, conn)
        translated.name  # Returns name in current locale (e.g., "Producto")

        render(conn, "show.html", product: translated)
      end

      # In a LiveView
      def mount(%{"id" => id}, _session, socket) do
        product = MyApp.Catalog.Product |> Ash.get!(id)

        # Uses locale from socket assigns
        translated = AshPhoenixTranslations.translate(product, socket)

        {:ok, assign(socket, product: translated)}
      end

      # Direct locale specification
      product = MyApp.Catalog.Product |> Ash.get!(id)

      spanish = AshPhoenixTranslations.translate(product, :es)
      spanish.name  # "Producto Español"

      french = AshPhoenixTranslations.translate(product, :fr)
      french.name  # "Produit Français"

      # Translate in a pipeline
      product =
        MyApp.Catalog.Product
        |> Ash.get!(id)
        |> AshPhoenixTranslations.translate(:es)

      # Access translated fields directly
      IO.puts(product.name)        # "Producto Español"
      IO.puts(product.description) # "Descripción en español"

  ## Locale Resolution

  The function attempts to find the locale in this order:

  1. **From Plug.Conn:**
     - `conn.assigns.locale` (fastest, no session fetch required)
     - `Plug.Conn.get_session(conn, :locale)` (if session is fetched)
     - Application config `:default_locale` (fallback)

  2. **From Phoenix.LiveView.Socket:**
     - `socket.assigns.__translation_locale__` (set by `update_locale/2`)
     - `socket.private.connect_params["locale"]` (from initial mount)
     - Application config `:default_locale` (fallback)

  3. **From Atom:**
     - Used directly

  ## What Gets Loaded

  The function loads all calculation fields defined by `translatable_attribute`:

      translations do
        translatable_attribute :name, :string, locales: [:en, :es, :fr]
        translatable_attribute :description, :text, locales: [:en, :es, :fr]
      end

  After translation, the resource will have:
  - `resource.name` - Translated name for the locale
  - `resource.description` - Translated description for the locale
  - All original fields unchanged (id, sku, created_at, etc.)

  ## Performance Considerations

  - Uses ETS-based caching (configurable TTL)
  - Only loads requested locale, not all locales
  - Calculations are lazy-loaded by Ash
  - Cache is automatically invalidated on updates

  ## Error Handling

      # If resource doesn't have translation extension
      plain_resource = AshPhoenixTranslations.translate(plain_resource, :es)
      # Returns the resource unchanged (no-op)

      # If locale is invalid or unsupported
      # Falls back to default_locale or fallback_locale

      # If translation is missing for a field
      product = AshPhoenixTranslations.translate(product, :de)
      product.name  # May return English if German is missing and fallback_locale: :en

  ## See Also

  - `translate_all/2` - Translate multiple resources efficiently
  - `live_translate/2` - LiveView-specific translation with reactive updates
  - `translate_field/3` - Get a single field translation directly
  - `available_locales/2` - Check which locales have translations

  """
  def translate(resource, conn_or_socket_or_locale)

  def translate(resource, %Plug.Conn{} = conn) do
    locale = get_locale(conn)
    do_translate(resource, locale)
  end

  def translate(resource, %Phoenix.LiveView.Socket{} = socket) do
    locale = get_locale(socket)
    do_translate(resource, locale)
  end

  def translate(resource, locale) when is_atom(locale) do
    do_translate(resource, locale)
  end

  @doc """
  Translate multiple resources efficiently based on the connection's locale.

  This function is optimized for translating lists of resources. It accepts the
  same locale sources as `translate/2` (Conn, Socket, or atom) and applies the
  translation to all resources in the list.

  ## Parameters

  - `resources` - List of Ash resource structs to translate
  - `conn_or_socket_or_locale` - Same as `translate/2` (Conn, Socket, or atom)

  ## Return Value

  Returns a list of translated resources, maintaining the original order.
  Each resource has its calculated translation fields loaded for the locale.

  ## Examples

      # Translate product list in controller
      def index(conn, _params) do
        products =
          MyApp.Catalog.Product
          |> Ash.read!()
          |> AshPhoenixTranslations.translate_all(conn)

        # All products now have translations in conn locale
        render(conn, "index.html", products: products)
      end

      # Translate with specific locale
      products = MyApp.Catalog.Product |> Ash.read!()
      spanish_products = AshPhoenixTranslations.translate_all(products, :es)

      Enum.each(spanish_products, fn product ->
        IO.puts(product.name)  # Prints Spanish names
      end)

      # Translate in LiveView
      def handle_event("load_products", _params, socket) do
        products =
          MyApp.Catalog.Product
          |> Ash.read!()
          |> AshPhoenixTranslations.translate_all(socket)

        {:noreply, assign(socket, products: products)}
      end

      # Empty list handling
      [] = AshPhoenixTranslations.translate_all([], :es)  # Returns []

      # Mix of resources (if same type)
      products = [product1, product2, product3]
      translated = AshPhoenixTranslations.translate_all(products, :fr)

      # Use in queries with filtering
      featured_products =
        MyApp.Catalog.Product
        |> Ash.Query.filter(featured == true)
        |> Ash.read!()
        |> AshPhoenixTranslations.translate_all(conn)

  ## Performance

  - Each resource is translated independently (parallelizable)
  - Uses the same caching strategy as `translate/2`
  - More efficient than calling `translate/2` in a loop (code clarity)
  - Actual Ash.load operations are batched internally

  ## Use Cases

  - **Product listings:** Translate all products in a catalog
  - **Search results:** Translate all items in search results
  - **API responses:** Bulk translate for JSON API endpoints
  - **Reports:** Translate data for internationalized reports

  ## Practical Example: Multi-locale Product Feed

      defmodule MyAppWeb.API.ProductController do
        use MyAppWeb, :controller
        import AshPhoenixTranslations

        def index(conn, %{"locale" => locale_str}) do
          locale = String.to_existing_atom(locale_str)

          products =
            MyApp.Catalog.Product
            |> Ash.Query.filter(published == true)
            |> Ash.read!()
            |> translate_all(locale)

          json(conn, %{
            products: Enum.map(products, fn p ->
              %{
                id: p.id,
                name: p.name,              # Translated
                description: p.description, # Translated
                price: p.price
              }
            end)
          })
        end
      end

  ## See Also

  - `translate/2` - Translate a single resource
  - `live_translate/2` - LiveView-specific translation
  - `translation_completeness/1` - Check translation coverage
  """
  def translate_all(resources, conn_or_socket_or_locale) when is_list(resources) do
    locale =
      case conn_or_socket_or_locale do
        %Plug.Conn{} = conn -> get_locale(conn)
        %Phoenix.LiveView.Socket{} = socket -> get_locale(socket)
        locale when is_atom(locale) -> locale
      end

    Enum.map(resources, &do_translate(&1, locale))
  end

  @doc """
  Live translate a resource for LiveView with reactive updates.

  This specialized function translates a resource for LiveView contexts and stores
  both the translated resource and the locale in socket assigns. This enables
  automatic retranslation when the locale changes via `update_locale/2`.

  ## Parameters

  - `resource` - The Ash resource struct to translate
  - `socket` - The Phoenix LiveView socket

  ## Return Value

  Returns a tuple `{translated_resource, updated_socket}`:
  - `translated_resource` - The resource with calculated translation fields loaded
  - `updated_socket` - Socket with updated assigns for reactive updates

  ## Socket Assigns Set

  - `__translated_resource__` - The translated resource (for retranslation)
  - `__translation_locale__` - The current locale (for tracking)

  ## Examples

      # Basic LiveView mount
      defmodule MyAppWeb.ProductLive.Show do
        use MyAppWeb, :live_view
        import AshPhoenixTranslations

        def mount(%{"id" => id}, _session, socket) do
          product = MyApp.Catalog.Product |> Ash.get!(id)

          # Translate and store for reactive updates
          {translated_product, socket} = live_translate(product, socket)

          {:ok, assign(socket, product: translated_product)}
        end

        # When locale changes, resource is automatically retranslated
        def handle_event("switch_locale", %{"locale" => locale}, socket) do
          socket = update_locale(socket, String.to_existing_atom(locale))
          # product is automatically retranslated!
          {:noreply, socket}
        end
      end

      # LiveView with multiple resources
      def mount(%{"category_id" => category_id}, _session, socket) do
        category = MyApp.Catalog.Category |> Ash.get!(category_id)
        products = MyApp.Catalog.Product |> Ash.Query.filter(category_id == ^category_id) |> Ash.read!()

        # Translate category with reactive support
        {translated_category, socket} = live_translate(category, socket)

        # Translate products normally (no reactive updates needed for lists)
        translated_products = translate_all(products, socket)

        socket =
          socket
          |> assign(:category, translated_category)
          |> assign(:products, translated_products)

        {:ok, socket}
      end

      # LiveView form with translation editing
      def mount(%{"id" => id}, _session, socket) do
        product = MyApp.Catalog.Product |> Ash.get!(id)
        {translated_product, socket} = live_translate(product, socket)

        # Get translatable attributes for form
        attrs = translatable_attributes(MyApp.Catalog.Product)

        socket =
          socket
          |> assign(:product, translated_product)
          |> assign(:translatable_attrs, attrs)
          |> assign(:editing_locale, :en)

        {:ok, socket}
      end

  ## Reactive Translation Flow

  1. Initial mount calls `live_translate/2`
  2. Resource is translated to current locale
  3. Resource and locale are stored in socket assigns
  4. When `update_locale/2` is called:
     - New locale is set in assigns
     - `__translated_resource__` is automatically retranslated
     - LiveView rerenders with new translations

  ## Performance Notes

  - Only retranslates when locale changes (efficient)
  - Uses same caching as `translate/2`
  - Stores reference to resource (not duplicate)
  - Automatic updates reduce manual translation code

  ## Comparison with `translate/2`

  Use `live_translate/2` when:
  - Single resource that needs reactive locale updates
  - Building interactive translation editors
  - Locale switching in LiveView

  Use `translate/2` when:
  - Lists of resources (use with `translate_all/2`)
  - Static content that doesn't change locale
  - Non-LiveView contexts (controllers, views)

  ## See Also

  - `update_locale/2` - Change locale and retrigger translation
  - `translate/2` - Regular translation without reactive updates
  - `translate_all/2` - Translate lists of resources
  """
  def live_translate(resource, %Phoenix.LiveView.Socket{} = socket) do
    locale = get_locale(socket)
    translated = do_translate(resource, locale)

    # Store in socket assigns for reactive updates
    socket =
      socket
      |> Phoenix.Component.assign(:__translated_resource__, translated)
      |> Phoenix.Component.assign(:__translation_locale__, locale)

    {translated, socket}
  end

  @doc """
  Update the locale for a LiveView socket and automatically retranslate resources.

  This function changes the active locale in a LiveView and triggers automatic
  retranslation of any resources that were set up with `live_translate/2`.

  ## Parameters

  - `socket` - The Phoenix LiveView socket
  - `locale` - The new locale as an atom (e.g., `:es`, `:fr`, `:de`)

  ## Return Value

  Returns the updated socket with:
  - `__translation_locale__` assign set to new locale
  - `__translated_resource__` retranslated to new locale (if present)

  ## Examples

      # Language switcher in LiveView
      defmodule MyAppWeb.ProductLive.Show do
        use MyAppWeb, :live_view
        import AshPhoenixTranslations

        def mount(%{"id" => id}, _session, socket) do
          product = MyApp.Catalog.Product |> Ash.get!(id)
          {translated_product, socket} = live_translate(product, socket)

          {:ok, assign(socket, product: translated_product)}
        end

        def handle_event("switch_locale", %{"locale" => locale_str}, socket) do
          locale = String.to_existing_atom(locale_str)

          # Update locale - product is automatically retranslated
          socket = update_locale(socket, locale)

          # Product in socket.assigns.product now has new translations
          {:noreply, socket}
        end
      end

      # Template with language switcher
      # <select phx-change="switch_locale">
      #   <option value="en">English</option>
      #   <option value="es">Español</option>
      #   <option value="fr">Français</option>
      # </select>

      # Programmatic locale change
      def handle_info({:locale_updated, new_locale}, socket) do
        socket = update_locale(socket, new_locale)
        {:noreply, socket}
      end

      # LiveView with locale from URL params
      def handle_params(%{"locale" => locale_str}, _url, socket) do
        locale = String.to_existing_atom(locale_str)
        socket = update_locale(socket, locale)

        {:noreply, socket}
      end

      # Multi-step form with locale persistence
      def handle_event("next_step", %{"locale" => locale_str}, socket) do
        locale = String.to_existing_atom(locale_str)

        socket =
          socket
          |> update_locale(locale)
          |> assign(:current_step, socket.assigns.current_step + 1)

        {:noreply, socket}
      end

  ## Important Notes

  ### Safe Atom Conversion

  Always convert user input to atoms safely:

      # ✓ Safe - validates and uses existing atom
      locale = String.to_existing_atom(locale_str)
      socket = update_locale(socket, locale)

      # ✗ UNSAFE - creates new atoms, potential DOS attack
      locale = String.to_atom(locale_str)  # DON'T DO THIS

  ### Validation

  For extra safety, validate locales before conversion:

      def handle_event("switch_locale", %{"locale" => locale_str}, socket) do
        case AshPhoenixTranslations.LocaleValidator.validate_locale(locale_str) do
          {:ok, locale} ->
            socket = update_locale(socket, locale)
            {:noreply, socket}

          {:error, :invalid_locale} ->
            {:noreply, put_flash(socket, :error, "Invalid locale")}
        end
      end

  ## What Gets Retranslated

  Only resources set up with `live_translate/2` are automatically retranslated.
  Other resources in assigns remain unchanged:

      # This product IS retranslated
      {product, socket} = live_translate(product, socket)

      # These products are NOT automatically retranslated
      products = translate_all(products, socket)

      # To retranslate lists manually:
      socket = update_locale(socket, :es)
      products = translate_all(socket.assigns.products, socket)
      socket = assign(socket, :products, products)

  ## See Also

  - `live_translate/2` - Set up resource for reactive translation
  - `translate/2` - Translate without reactive updates
  - `translate_all/2` - Translate lists of resources
  """
  def update_locale(%Phoenix.LiveView.Socket{} = socket, locale) when is_atom(locale) do
    socket
    |> Phoenix.Component.assign(:__translation_locale__, locale)
    |> maybe_retranslate_resources()
  end

  defp do_translate(resource, locale) do
    resource_module = resource.__struct__

    # Get translatable attributes from the extension
    translatable_attrs = AshPhoenixTranslations.Info.translatable_attributes(resource_module)

    # For each translatable attribute, there's a calculation with its name
    calculations =
      translatable_attrs
      |> Enum.map(& &1.name)

    # Load the calculations with locale context
    if Enum.empty?(calculations) do
      resource
    else
      resource
      |> Ash.load!(calculations, authorize?: false, context: %{locale: locale})
    end
  end

  defp get_locale(%Plug.Conn{} = conn) do
    # Check assigns first (doesn't require fetch_session), then session
    conn.assigns[:locale] ||
      (conn.private[:plug_session_fetch] && Plug.Conn.get_session(conn, :locale)) ||
      Application.get_env(:ash_phoenix_translations, :default_locale, :en)
  end

  defp get_locale(%Phoenix.LiveView.Socket{} = socket) do
    socket.assigns[:__translation_locale__] ||
      Map.get(socket.private.connect_params || %{}, "locale") ||
      Application.get_env(:ash_phoenix_translations, :default_locale, :en)
  end

  defp maybe_retranslate_resources(%Phoenix.LiveView.Socket{} = socket) do
    case socket.assigns[:__translated_resource__] do
      nil ->
        socket

      resource ->
        locale = socket.assigns[:__translation_locale__]
        retranslated = do_translate(resource, locale)
        Phoenix.Component.assign(socket, :__translated_resource__, retranslated)
    end
  end

  @doc """
  Get a specific translation for a field without loading calculations.

  This function retrieves a translation directly from the storage field
  (e.g., `name_translations`), bypassing the calculation system. Useful
  for accessing translations without triggering Ash calculations.

  ## Parameters

  - `resource` - The Ash resource struct
  - `field` - The translatable field name (atom, e.g., `:name`)
  - `locale` - The locale to retrieve (atom, e.g., `:es`)

  ## Return Value

  - The translation string if present
  - `nil` if the translation doesn't exist

  ## Examples

      product = MyApp.Catalog.Product |> Ash.get!(id)

      # Get Spanish name directly
      spanish_name = AshPhoenixTranslations.translate_field(product, :name, :es)
      # => "Producto Español"

      # Get French description
      french_desc = AshPhoenixTranslations.translate_field(product, :description, :fr)
      # => "Description en français"

      # Missing translation returns nil
      german_name = AshPhoenixTranslations.translate_field(product, :name, :de)
      # => nil

      # Use in templates
      <h1><%= translate_field(@product, :name, @locale) %></h1>

      # Check before rendering
      case translate_field(@product, :tagline, :es) do
        nil -> "Default tagline"
        tagline -> tagline
      end

      # Build locale-specific data structures
      translations_map = for locale <- [:en, :es, :fr], into: %{} do
        {locale, translate_field(product, :name, locale)}
      end
      # => %{en: "Product", es: "Producto", fr: "Produit"}

  ## Use Cases

  ### Direct Access Without Calculation Loading

  Use when you need raw translation data without Ash calculations:

      # Get all locales for a field
      product = MyApp.Catalog.Product |> Ash.get!(id)

      all_name_translations =
        [:en, :es, :fr, :de]
        |> Enum.map(fn locale ->
          {locale, translate_field(product, :name, locale)}
        end)
        |> Enum.into(%{})

  ### API Responses with Multiple Locales

      defmodule MyAppWeb.API.ProductController do
        def show(conn, %{"id" => id}) do
          product = MyApp.Catalog.Product |> Ash.get!(id)

          json(conn, %{
            id: product.id,
            translations: %{
              name: %{
                en: translate_field(product, :name, :en),
                es: translate_field(product, :name, :es),
                fr: translate_field(product, :name, :fr)
              },
              description: %{
                en: translate_field(product, :description, :en),
                es: translate_field(product, :description, :es),
                fr: translate_field(product, :description, :fr)
              }
            }
          })
        end
      end

  ### Translation Completeness Check

      def check_translation_status(product, locale) do
        attrs = AshPhoenixTranslations.translatable_attributes(product.__struct__)

        Enum.map(attrs, fn attr ->
          value = translate_field(product, attr.name, locale)
          {attr.name, present?(value)}
        end)
      end

      defp present?(nil), do: false
      defp present?(""), do: false
      defp present?(_), do: true

  ## Performance

  - No Ash.load call (faster than `translate/2` for single fields)
  - No caching (direct map access)
  - Useful for batch operations where you manually control caching

  ## Comparison with `translate/2`

  **Use `translate_field/3` when:**
  - You need a single translation value
  - Performance is critical (skips calculation loading)
  - Building custom data structures
  - API responses with multiple locales

  **Use `translate/2` when:**
  - You need all fields translated
  - You want caching benefits
  - You're rendering in templates (automatic escaping)
  - You want fallback chain support

  ## See Also

  - `translate/2` - Translate entire resource with caching
  - `available_locales/2` - Get list of available locales for a field
  - `translation_completeness/1` - Calculate overall completeness
  """
  def translate_field(resource, field, locale) do
    storage_field = AshPhoenixTranslations.Info.storage_field(field)

    case Map.get(resource, storage_field) do
      nil -> nil
      translations when is_map(translations) -> Map.get(translations, locale)
    end
  end

  @doc """
  Get all available locales for a specific field on a resource.

  Returns a list of locales that have non-empty translations for the specified
  field. Useful for determining which languages are available for a particular
  resource and field combination.

  ## Parameters

  - `resource` - The Ash resource struct
  - `field` - The translatable field name (atom, e.g., `:name`)

  ## Return Value

  Returns a list of atoms representing locales with non-empty translations.
  Empty strings and `nil` values are considered missing translations.

  ## Examples

      product = MyApp.Catalog.Product |> Ash.get!(id)

      # Get available locales for product name
      name_locales = AshPhoenixTranslations.available_locales(product, :name)
      # => [:en, :es, :fr]  (only these have translations)

      # Check description availability
      desc_locales = AshPhoenixTranslations.available_locales(product, :description)
      # => [:en, :es]  (French description is missing)

      # Empty field returns empty list
      tagline_locales = AshPhoenixTranslations.available_locales(product, :tagline)
      # => []  (no translations exist)

  ## Use Cases

  ### Dynamic Language Selector

  Show only languages that have translations:

      def render_language_selector(product) do
        available = AshPhoenixTranslations.available_locales(product, :name)

        for locale <- available do
          link(locale_name(locale), to: "/products/\#{product.id}?locale=\#{locale}")
        end
      end

  ### Translation Progress Indicator

      defmodule MyAppWeb.ProductLive.TranslationStatus do
        def mount(%{"id" => id}, _session, socket) do
          product = MyApp.Catalog.Product |> Ash.get!(id)
          attrs = AshPhoenixTranslations.translatable_attributes(product.__struct__)

          # Build status matrix
          status =
            Enum.map(attrs, fn attr ->
              available = available_locales(product, attr.name)
              missing = attr.locales -- available

              %{
                field: attr.name,
                available: available,
                missing: missing,
                completeness: length(available) / length(attr.locales) * 100
              }
            end)

          {:ok, assign(socket, translation_status: status)}
        end
      end

  ### API Filter

  Filter resources by translation availability:

      def products_with_locale(locale) do
        MyApp.Catalog.Product
        |> Ash.read!()
        |> Enum.filter(fn product ->
          locale in available_locales(product, :name)
        end)
      end

  ### Validation

  Ensure required locales have translations:

      def validate_required_translations(product, required_locales) do
        attrs = AshPhoenixTranslations.translatable_attributes(product.__struct__)

        Enum.reduce(attrs, [], fn attr, errors ->
          available = available_locales(product, attr.name)
          missing = required_locales -- available

          if Enum.empty?(missing) do
            errors
          else
            [
              {attr.name, "Missing required translations: \#{inspect(missing)}"}
              | errors
            ]
          end
        end)
      end

  ### Translation Dashboard

      defmodule MyAppWeb.TranslationDashboard do
        def mount(_params, _session, socket) do
          products = MyApp.Catalog.Product |> Ash.read!()

          # Calculate statistics
          stats =
            Enum.reduce(products, %{}, fn product, acc ->
              name_locales = available_locales(product, :name)
              desc_locales = available_locales(product, :description)

              Enum.reduce(name_locales, acc, fn locale, inner_acc ->
                Map.update(inner_acc, locale, 1, &(&1 + 1))
              end)
            end)

          {:ok, assign(socket, locale_stats: stats)}
        end
      end

  ## Template Usage

      # Show available language flags
      <div class="language-flags">
        <%= for locale <- available_locales(@product, :name) do %>
          <button phx-click="switch_locale" phx-value-locale={locale}>
            <%= flag_emoji(locale) %>
          </button>
        <% end %>
      </div>

      # Translation status badge
      <% available_count = length(available_locales(@product, :name)) %>
      <% total_count = length(translatable_attributes(@product.__struct__)) %>
      <span class="badge">
        <%= available_count %>/<%= total_count %> languages
      </span>

  ## Performance

  - Direct map access (fast)
  - No database queries
  - Filters out nil and empty string values
  - Returns list (not MapSet) for template compatibility

  ## See Also

  - `translate_field/3` - Get specific translation value
  - `translation_completeness/1` - Calculate overall completeness percentage
  - `translatable_attributes/1` - Get list of translatable attributes
  """
  def available_locales(resource, field) do
    storage_field = AshPhoenixTranslations.Info.storage_field(field)

    case Map.get(resource, storage_field) do
      nil ->
        []

      translations when is_map(translations) ->
        translations
        |> Map.keys()
        |> Enum.filter(fn locale -> translations[locale] not in [nil, ""] end)
    end
  end

  @doc """
  Calculate translation completeness percentage for a resource.

  Analyzes all translatable fields on a resource and calculates what percentage
  of translations are present (non-nil, non-empty). Useful for progress
  indicators, quality metrics, and validation.

  ## Parameters

  - `resource` - The Ash resource struct to analyze

  ## Return Value

  Returns a float between `0.0` and `100.0`:
  - `100.0` - All translations are present
  - `0.0` - No translations exist
  - Values in between represent partial completion

  ## Calculation Method

  ```
  completeness = (present_translations / total_possible_translations) * 100
  ```

  Where:
  - `total_possible_translations` = sum of all locale counts across all translatable attributes
  - `present_translations` = count of non-nil, non-empty translation values

  ## Examples

      product = MyApp.Catalog.Product |> Ash.get!(id)

      # Get overall completeness
      completeness = AshPhoenixTranslations.translation_completeness(product)
      # => 75.0

      # Interpretation:
      # - Product has 2 translatable fields (name, description)
      # - Each field supports 4 locales [:en, :es, :fr, :de]
      # - Total possible: 2 * 4 = 8 translations
      # - Present: 6 translations (English, Spanish, French for both fields)
      # - Completeness: 6 / 8 * 100 = 75.0%

      # No translations yet
      new_product = MyApp.Catalog.Product.create!(%{sku: "NEW-001"})
      completeness = translation_completeness(new_product)
      # => 0.0

      # Fully translated
      complete_product = MyApp.Catalog.Product |> Ash.get!("fully-translated-id")
      completeness = translation_completeness(complete_product)
      # => 100.0

  ## Use Cases

  ### Progress Bar in UI

      defmodule MyAppWeb.ProductLive.TranslationEditor do
        def mount(%{"id" => id}, _session, socket) do
          product = MyApp.Catalog.Product |> Ash.get!(id)
          completeness = translation_completeness(product)

          socket =
            socket
            |> assign(:product, product)
            |> assign(:completeness, completeness)
            |> assign(:completeness_class, completeness_class(completeness))

          {:ok, socket}
        end

        defp completeness_class(pct) when pct == 100.0, do: "bg-green-500"
        defp completeness_class(pct) when pct >= 75.0, do: "bg-yellow-500"
        defp completeness_class(_pct), do: "bg-red-500"
      end

      # Template:
      # <div class="progress-bar">
      #   <div class={"progress-fill <%= @completeness_class %>"} style={"width: <%= @completeness %>%"}>
      #     <%= Float.round(@completeness, 1) %>%
      #   </div>
      # </div>

  ### Quality Gate

  Prevent publishing until translations are complete:

      defmodule MyApp.Catalog.Product do
        # ... resource definition ...

        actions do
          update :publish do
            validate fn changeset, _context ->
              product = changeset.data
              completeness = AshPhoenixTranslations.translation_completeness(product)

              if completeness < 100.0 do
                {:error,
                 field: :translations,
                 message: "All translations must be complete before publishing (currently \#{completeness}%)"}
              else
                :ok
              end
            end

            change fn changeset, _context ->
              Ash.Changeset.force_change_attribute(changeset, :published, true)
            end
          end
        end
      end

  ### Dashboard Statistics

      defmodule MyAppWeb.TranslationDashboard do
        def mount(_params, _session, socket) do
          products = MyApp.Catalog.Product |> Ash.read!()

          # Calculate statistics
          stats = %{
            total: length(products),
            complete: Enum.count(products, fn p -> translation_completeness(p) == 100.0 end),
            partial: Enum.count(products, fn p ->
              c = translation_completeness(p)
              c > 0.0 and c < 100.0
            end),
            empty: Enum.count(products, fn p -> translation_completeness(p) == 0.0 end),
            average: Enum.sum(Enum.map(products, &translation_completeness/1)) / length(products)
          }

          {:ok, assign(socket, translation_stats: stats)}
        end
      end

  ### Sorting and Filtering

  Find products that need translation work:

      # Products with incomplete translations
      incomplete_products =
        MyApp.Catalog.Product
        |> Ash.read!()
        |> Enum.filter(fn product ->
          translation_completeness(product) < 100.0
        end)
        |> Enum.sort_by(&translation_completeness/1)

      # Lowest completeness first (needs most work)
      needs_work = Enum.take(incomplete_products, 10)

  ### Batch Processing Prioritization

      defmodule MyApp.TranslationWorker do
        def prioritize_translation_work do
          products =
            MyApp.Catalog.Product
            |> Ash.read!()
            |> Enum.map(fn product ->
              {product, translation_completeness(product)}
            end)
            |> Enum.filter(fn {_product, completeness} -> completeness < 100.0 end)
            |> Enum.sort_by(fn {_product, completeness} -> completeness end)

          # Work on least complete first
          Enum.each(products, fn {product, completeness} ->
            Logger.info("Translating \#{product.sku}: \#{completeness}% complete")
            send_to_translation_service(product)
          end)
        end
      end

  ### API Response

  Include completeness in API responses:

      def show(conn, %{"id" => id}) do
        product = MyApp.Catalog.Product |> Ash.get!(id)

        json(conn, %{
          id: product.id,
          name: product.name,
          price: product.price,
          translation_completeness: translation_completeness(product),
          available_locales: available_locales(product, :name)
        })
      end

  ## Performance

  - Iterates through all translatable attributes once
  - Accesses storage maps directly (no database queries)
  - Returns cached float value (efficient for repeated calls)
  - O(n) where n = number of translatable attributes * number of locales

  ## Edge Cases

      # Resource with no translatable attributes
      plain_resource = MyApp.NonTranslatableResource |> Ash.get!(id)
      completeness = translation_completeness(plain_resource)
      # => 100.0  (considered "complete" if no translations needed)

      # Empty resource (no translations yet)
      new_product = MyApp.Catalog.Product.create!(%{})
      completeness = translation_completeness(new_product)
      # => 0.0  (no translations present)

  ## See Also

  - `available_locales/2` - Check which locales have translations for a field
  - `translate_field/3` - Access individual translation values
  - `translatable_attributes/1` - Get list of translatable attributes with metadata
  """
  def translation_completeness(resource) do
    resource_module = resource.__struct__
    attrs = AshPhoenixTranslations.Info.translatable_attributes(resource_module)

    if Enum.empty?(attrs) do
      100.0
    else
      total_translations =
        Enum.reduce(attrs, 0, fn attr, acc ->
          acc + length(attr.locales)
        end)

      present_translations =
        Enum.reduce(attrs, 0, fn attr, acc ->
          storage_field = AshPhoenixTranslations.Info.storage_field(attr.name)
          translations = Map.get(resource, storage_field, %{})

          present =
            attr.locales
            |> Enum.count(fn locale ->
              case Map.get(translations, locale) do
                nil -> false
                "" -> false
                _ -> true
              end
            end)

          acc + present
        end)

      if total_translations == 0 do
        100.0
      else
        present_translations / total_translations * 100.0
      end
    end
  end

  @doc """
  Get metadata about all translatable attributes for a resource.

  Returns a list of `TranslatableAttribute` structs containing configuration
  and metadata for each translatable field. This is essential for building
  translation editors, validation logic, and introspecting translation
  capabilities at runtime.

  ## Parameters

  - `resource_module` - The Ash resource module (e.g., `MyApp.Catalog.Product`)

  ## Return Value

  Returns a list of `%AshPhoenixTranslations.TranslatableAttribute{}` structs,
  each containing:

  - `name` - The field name (atom, e.g., `:name`)
  - `type` - The field type (`:string`, `:text`, etc.)
  - `locales` - List of supported locales (e.g., `[:en, :es, :fr]`)
  - `required` - List of locales that must have values (e.g., `[:en]`)
  - `markdown` - Whether markdown rendering is enabled (`true`/`false`)
  - `fallback_locale` - Fallback locale for missing translations (atom or `nil`)

  ## Examples

      # Get translatable attributes
      attrs = AshPhoenixTranslations.translatable_attributes(MyApp.Catalog.Product)
      # => [
      #   %TranslatableAttribute{
      #     name: :name,
      #     type: :string,
      #     locales: [:en, :es, :fr, :de],
      #     required: [:en],
      #     markdown: false,
      #     fallback_locale: nil
      #   },
      #   %TranslatableAttribute{
      #     name: :description,
      #     type: :text,
      #     locales: [:en, :es, :fr, :de],
      #     required: [:en],
      #     markdown: true,
      #     fallback_locale: :en
      #   }
      # ]

      # Access attribute properties
      attrs = translatable_attributes(MyApp.Catalog.Product)
      name_attr = Enum.find(attrs, fn attr -> attr.name == :name end)

      name_attr.locales      # [:en, :es, :fr, :de]
      name_attr.required     # [:en]
      name_attr.markdown     # false

      # Get all field names
      field_names = Enum.map(attrs, & &1.name)
      # => [:name, :description, :tagline]

      # Check if field supports a locale
      attrs
      |> Enum.find(fn attr -> attr.name == :description end)
      |> then(fn attr -> :es in attr.locales end)
      # => true

      # Find fields requiring English translation
      attrs
      |> Enum.filter(fn attr -> :en in attr.required end)
      |> Enum.map(& &1.name)
      # => [:name, :description]

  ## Use Cases

  ### Building Translation Editors

  Create dynamic forms based on translatable fields:

      defmodule MyAppWeb.ProductLive.TranslationEditor do
        use MyAppWeb, :live_view
        import AshPhoenixTranslations

        def mount(%{"id" => id}, _session, socket) do
          product = MyApp.Catalog.Product |> Ash.get!(id)
          attrs = translatable_attributes(MyApp.Catalog.Product)

          # Build form data
          form_fields =
            Enum.map(attrs, fn attr ->
              translations =
                Enum.map(attr.locales, fn locale ->
                  value = translate_field(product, attr.name, locale)
                  required = locale in attr.required

                  %{
                    locale: locale,
                    value: value,
                    required: required,
                    present: value not in [nil, ""]
                  }
                end)

              %{
                field: attr.name,
                type: attr.type,
                markdown: attr.markdown,
                translations: translations
              }
            end)

          socket =
            socket
            |> assign(:product, product)
            |> assign(:form_fields, form_fields)

          {:ok, socket}
        end
      end

  ### Validation Logic

  Validate that required translations are present:

      defmodule MyApp.Catalog.Product.Changes.ValidateTranslations do
        use Ash.Resource.Change

        def change(changeset, _opts, _context) do
          product = changeset.data
          attrs = AshPhoenixTranslations.translatable_attributes(product.__struct__)

          errors =
            Enum.flat_map(attrs, fn attr ->
              Enum.reduce(attr.required, [], fn locale, acc ->
                value = AshPhoenixTranslations.translate_field(product, attr.name, locale)

                if value in [nil, ""] do
                  [
                    {attr.name,
                     "Translation required for locale \#{locale}"}
                    | acc
                  ]
                else
                  acc
                end
              end)
            end)

          if Enum.empty?(errors) do
            changeset
          else
            Ash.Changeset.add_error(changeset, errors)
          end
        end
      end

  ### Field Introspection

  Discover translation capabilities at runtime:

      def translation_capabilities(resource_module) do
        attrs = translatable_attributes(resource_module)

        %{
          fields: Enum.map(attrs, & &1.name),
          total_fields: length(attrs),
          supported_locales: attrs |> Enum.flat_map(& &1.locales) |> Enum.uniq(),
          markdown_fields: attrs |> Enum.filter(& &1.markdown) |> Enum.map(& &1.name),
          required_locales: attrs |> Enum.flat_map(& &1.required) |> Enum.uniq()
        }
      end

      # Usage
      caps = translation_capabilities(MyApp.Catalog.Product)
      # => %{
      #   fields: [:name, :description, :tagline],
      #   total_fields: 3,
      #   supported_locales: [:en, :es, :fr, :de],
      #   markdown_fields: [:description],
      #   required_locales: [:en]
      # }

  ### Translation Progress Tracking

  Track completion by field:

      def field_translation_progress(product) do
        attrs = translatable_attributes(product.__struct__)

        Enum.map(attrs, fn attr ->
          available = available_locales(product, attr.name)
          total = length(attr.locales)
          present = length(available)

          %{
            field: attr.name,
            total_locales: total,
            present_locales: present,
            missing_locales: attr.locales -- available,
            completeness: if(total > 0, do: present / total * 100, else: 100.0),
            required_missing: attr.required -- available
          }
        end)
      end

  ### Dynamic Form Generation

  Generate translation forms automatically:

      # Template
      <%= for attr <- @translatable_attrs do %>
        <fieldset class="translation-field">
          <legend><%= humanize(attr.name) %></legend>

          <%= for locale <- attr.locales do %>
            <div class="translation-input">
              <label>
                <%= locale %>
                <%= if locale in attr.required do %>
                  <span class="required">*</span>
                <% end %>
              </label>

              <%= if attr.markdown do %>
                <textarea
                  name={"product[\#{attr.name}_translations][\#{locale}]"}
                  rows="10"
                  phx-debounce="500">
                  <%= translate_field(@product, attr.name, locale) %>
                </textarea>
                <small>Markdown enabled</small>
              <% else %>
                <input
                  type="text"
                  name={"product[\#{attr.name}_translations][\#{locale}]"}
                  value={translate_field(@product, attr.name, locale)}
                  phx-debounce="500"
                />
              <% end %>
            </div>
          <% end %>
        </fieldset>
      <% end %>

  ## Practical Example: Complete Translation Dashboard

      defmodule MyAppWeb.TranslationDashboard do
        use MyAppWeb, :live_view
        import AshPhoenixTranslations

        def mount(_params, _session, socket) do
          products = MyApp.Catalog.Product |> Ash.read!()
          attrs = translatable_attributes(MyApp.Catalog.Product)

          # Calculate comprehensive statistics
          stats = %{
            total_products: length(products),
            translatable_fields: length(attrs),
            supported_locales: attrs |> Enum.flat_map(& &1.locales) |> Enum.uniq(),

            # Per-field statistics
            field_stats: Enum.map(attrs, fn attr ->
              {attr.name, calculate_field_stats(products, attr)}
            end) |> Enum.into(%{}),

            # Per-locale statistics
            locale_stats: calculate_locale_stats(products, attrs),

            # Overall health
            overall_completeness: calculate_overall_completeness(products)
          }

          {:ok, assign(socket, stats: stats, attrs: attrs)}
        end

        defp calculate_field_stats(products, attr) do
          Enum.reduce(attr.locales, %{}, fn locale, acc ->
            count = Enum.count(products, fn product ->
              value = translate_field(product, attr.name, locale)
              value not in [nil, ""]
            end)

            Map.put(acc, locale, %{
              present: count,
              missing: length(products) - count,
              percentage: count / length(products) * 100
            })
          end)
        end

        defp calculate_locale_stats(products, attrs) do
          all_locales = attrs |> Enum.flat_map(& &1.locales) |> Enum.uniq()

          Enum.map(all_locales, fn locale ->
            total_possible = length(products) * length(attrs)
            present = Enum.count(products, fn product ->
              Enum.all?(attrs, fn attr ->
                value = translate_field(product, attr.name, locale)
                value not in [nil, ""]
              end)
            end)

            {locale, %{
              complete_products: present,
              percentage: if(total_possible > 0, do: present / total_possible * 100, else: 0.0)
            }}
          end)
          |> Enum.into(%{})
        end

        defp calculate_overall_completeness(products) do
          Enum.sum(Enum.map(products, &translation_completeness/1)) / length(products)
        end
      end

  ## Performance

  - Lightweight operation (reads from extension metadata)
  - No database queries
  - Results can be cached for duration of request
  - O(1) lookup from resource module

  ## Comparison with Info Module

  These are equivalent:

      # Using main module (shorter, more convenient)
      attrs = AshPhoenixTranslations.translatable_attributes(MyApp.Product)

      # Using Info module directly (more explicit)
      attrs = AshPhoenixTranslations.Info.translatable_attributes(MyApp.Product)

  The main module version is provided for convenience and consistency with
  other helper functions like `translate/2` and `translate_field/3`.

  ## See Also

  - `translate_field/3` - Access individual translation values
  - `available_locales/2` - Check which locales have translations
  - `translation_completeness/1` - Calculate overall completeness
  - `AshPhoenixTranslations.Info` - Direct access to extension metadata
  """
  def translatable_attributes(resource_module) do
    AshPhoenixTranslations.Info.translatable_attributes(resource_module)
  end
end
