# Configuration Guide

Comprehensive configuration guide for AshPhoenixTranslations.

## Table of Contents

1. [Backend Selection](#backend-selection)
2. [Resource Configuration](#resource-configuration)
3. [Locale Configuration](#locale-configuration)
4. [Cache Configuration](#cache-configuration)
5. [Policy Configuration](#policy-configuration)
6. [Phoenix Integration](#phoenix-integration)
7. [Environment-Specific Configuration](#environment-specific-configuration)
8. [Advanced Configuration](#advanced-configuration)
9. [Performance Tuning](#performance-tuning)
10. [Troubleshooting](#troubleshooting)

---

## Backend Selection

AshPhoenixTranslations supports two storage backends with different trade-offs.

### Database Backend

Stores translations in JSONB columns (PostgreSQL) or Map fields (ETS).

#### When to Use Database Backend

✅ **Best For**:
- Dynamic translation updates without deployment
- User-editable content (e-commerce, CMS)
- Audit trail requirements
- Frequent translation changes
- Multi-tenant applications with different translations per tenant

❌ **Not Ideal For**:
- Static UI labels and messages
- High-performance read-heavy workloads (without caching)
- Applications with thousands of translations

#### Database Backend Configuration

```elixir
# lib/my_app/shop/product.ex
defmodule MyApp.Shop.Product do
  use Ash.Resource,
    domain: MyApp.Shop,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshPhoenixTranslations]

  translations do
    translatable_attribute :name, :string do
      locales [:en, :es, :fr, :de]
      required [:en]
    end

    backend :database
    cache_ttl 3600        # Cache for 1 hour
    audit_changes true    # Track translation changes
  end

  postgres do
    table "products"
    repo MyApp.Repo
  end
end
```

**Storage Structure**:
```elixir
# Generated storage field: name_translations
%Product{
  id: "123",
  name_translations: %{
    en: "Product Name",
    es: "Nombre del Producto",
    fr: "Nom du Produit",
    de: "Produktname"
  }
}
```

### Gettext Backend

Integrates with Phoenix's Gettext for POT/PO file-based translations.

#### When to Use Gettext Backend

✅ **Best For**:
- Static UI labels and error messages
- Professional translation workflows with CAT tools
- Compiled translations (faster runtime)
- Integration with existing Gettext infrastructure
- Large translation catalogs

❌ **Not Ideal For**:
- User-editable content
- Dynamic translation updates
- Per-resource translation audit trails

#### Gettext Backend Configuration

```elixir
# lib/my_app/shop/product.ex
defmodule MyApp.Shop.Product do
  use Ash.Resource,
    domain: MyApp.Shop,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshPhoenixTranslations]

  translations do
    translatable_attribute :name, :string do
      locales [:en, :es, :fr, :de]
      required [:en]
    end

    backend :gettext
    gettext_module MyApp.Gettext  # Optional, defaults to app gettext
  end
end
```

**Directory Structure**:
```
priv/gettext/
├── en/
│   └── LC_MESSAGES/
│       └── products.po
├── es/
│   └── LC_MESSAGES/
│       └── products.po
├── fr/
│   └── LC_MESSAGES/
│       └── products.po
└── products.pot  # Template file
```

**POT/PO File Structure**:
```po
# priv/gettext/products.pot
msgid "product_123_name"
msgstr ""

# priv/gettext/es/LC_MESSAGES/products.po
msgid "product_123_name"
msgstr "Nombre del Producto"
```

---

## Resource Configuration

### Translatable Attributes

Define which attributes support translations.

#### Basic Configuration

```elixir
translations do
  translatable_attribute :name, :string do
    locales [:en, :es, :fr]
    required [:en]              # Must provide English
    fallback :en                # Fallback to English if missing
  end
end
```

#### All Options

```elixir
translatable_attribute :description, :text do
  # Locale Configuration
  locales [:en, :es, :fr, :de, :ja]  # Supported locales
  required [:en]                       # Required translations
  fallback :en                         # Fallback locale

  # Type Configuration
  # Supported types: :string, :text, :integer, :decimal, :boolean, :date, :datetime

  # Validation
  validation max_length: 500
  validation min_length: 10

  # Formatting
  markdown true                        # Enable Markdown rendering
  sanitize true                        # Sanitize HTML in translations

  # Metadata
  description "Product description with rich formatting"
  public? true                         # API visibility
end
```

#### Multiple Attributes

```elixir
translations do
  # Product name - required, short
  translatable_attribute :name, :string do
    locales [:en, :es, :fr, :de]
    required [:en]
    validation max_length: 200
  end

  # Product description - optional, long-form
  translatable_attribute :description, :text do
    locales [:en, :es, :fr, :de]
    fallback :en
    markdown true
  end

  # SEO meta title
  translatable_attribute :meta_title, :string do
    locales [:en, :es, :fr, :de]
    fallback :en
    validation max_length: 60
  end

  # SEO meta description
  translatable_attribute :meta_description, :string do
    locales [:en, :es, :fr, :de]
    fallback :en
    validation max_length: 160
  end

  backend :database
  cache_ttl 7200
  audit_changes true
end
```

### Backend Options

```elixir
translations do
  # ... translatable attributes ...

  # Backend Selection
  backend :database  # or :gettext

  # Cache Configuration (Database backend only)
  cache_ttl 3600     # Seconds, default: 3600 (1 hour)

  # Audit Configuration (Database backend only)
  audit_changes true # Track who/when translations change

  # Gettext Configuration (Gettext backend only)
  gettext_module MyApp.Gettext       # Default: MyApp.Gettext
  gettext_domain "products"          # Default: resource name
end
```

---

## Locale Configuration

### Application-Wide Locale Configuration

Configure default and supported locales at the application level.

```elixir
# config/config.exs
config :my_app, MyApp.Gettext,
  default_locale: "en",
  locales: ~w(en es fr de ja zh pt)

# Fallback chain configuration
config :ash_phoenix_translations,
  fallback_chain: [
    ja: [:en],           # Japanese falls back to English
    zh: [:en],           # Chinese falls back to English
    pt: [:es, :en],      # Portuguese falls back to Spanish, then English
    de: [:en],           # German falls back to English
    fr: [:en]            # French falls back to English
  ]
```

### Per-Environment Locale Configuration

```elixir
# config/dev.exs
config :my_app, MyApp.Gettext,
  default_locale: "en",
  locales: ~w(en es fr)  # Limited locales in development

# config/prod.exs
config :my_app, MyApp.Gettext,
  default_locale: "en",
  locales: ~w(en es fr de ja zh pt ru ar)  # All locales in production
```

### Runtime Locale Configuration

```elixir
# Set locale per request
defmodule MyAppWeb.SetLocalePlug do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    locale = get_locale_from_request(conn)
    Gettext.put_locale(MyApp.Gettext, locale)
    assign(conn, :locale, locale)
  end

  defp get_locale_from_request(conn) do
    # Priority order:
    # 1. Query parameter (?locale=es)
    # 2. Session
    # 3. User preference
    # 4. Accept-Language header
    # 5. Default locale

    conn
    |> get_locale_from_params()
    |> Kernel.||(get_locale_from_session(conn))
    |> Kernel.||(get_locale_from_user(conn))
    |> Kernel.||(get_locale_from_header(conn))
    |> Kernel.||("en")
  end

  defp get_locale_from_params(conn) do
    conn.params["locale"]
  end

  defp get_locale_from_session(conn) do
    get_session(conn, :locale)
  end

  defp get_locale_from_user(conn) do
    case conn.assigns[:current_user] do
      %{locale: locale} -> locale
      _ -> nil
    end
  end

  defp get_locale_from_header(conn) do
    case get_req_header(conn, "accept-language") do
      [value | _] ->
        value
        |> String.split(",")
        |> List.first()
        |> String.split(";")
        |> List.first()
        |> String.downcase()

      _ ->
        nil
    end
  end
end
```

### Multi-Tenant Locale Configuration

```elixir
# Different locales per tenant
defmodule MyApp.TenantLocalePlug do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    tenant = conn.assigns[:current_tenant]

    locales = case tenant do
      %{region: "eu"} -> [:en, :es, :fr, :de]
      %{region: "asia"} -> [:en, :ja, :zh]
      %{region: "latam"} -> [:es, :pt, :en]
      _ -> [:en]
    end

    conn
    |> assign(:supported_locales, locales)
    |> assign(:locale, get_tenant_locale(conn, tenant, locales))
  end

  defp get_tenant_locale(conn, tenant, supported_locales) do
    requested_locale = conn.params["locale"] || tenant.default_locale || "en"

    if Enum.member?(supported_locales, String.to_atom(requested_locale)) do
      requested_locale
    else
      List.first(supported_locales) |> Atom.to_string()
    end
  end
end
```

---

## Cache Configuration

### Cache TTL Configuration

```elixir
# Resource-level cache TTL
translations do
  translatable_attribute :name, :string do
    locales [:en, :es, :fr]
  end

  backend :database
  cache_ttl 7200  # 2 hours
end
```

### Application-Wide Cache Configuration

```elixir
# config/config.exs
config :ash_phoenix_translations, AshPhoenixTranslations.Cache,
  ttl: 3600,              # Default TTL in seconds
  max_size: 10_000,       # Max cache entries
  cleanup_interval: 300   # Cleanup every 5 minutes
```

### Environment-Specific Cache Configuration

```elixir
# config/dev.exs
config :ash_phoenix_translations, AshPhoenixTranslations.Cache,
  ttl: 60,                # 1 minute in development
  max_size: 1_000

# config/prod.exs
config :ash_phoenix_translations, AshPhoenixTranslations.Cache,
  ttl: 7200,              # 2 hours in production
  max_size: 50_000
```

### Disable Caching

```elixir
# Disable cache for specific resource
translations do
  translatable_attribute :name, :string do
    locales [:en, :es]
  end

  backend :database
  cache_ttl 0  # Disable caching
end

# Or disable globally
config :ash_phoenix_translations, AshPhoenixTranslations.Cache,
  enabled: false
```

### Cache Warming

Preload frequently accessed translations into cache at application startup.

```elixir
# lib/my_app/application.ex
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      # ... other children ...
      {AshPhoenixTranslations.Cache, []},
      {Task, fn -> warm_translation_cache() end}
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp warm_translation_cache do
    # Wait for cache to initialize
    Process.sleep(100)

    # Warm product translations
    MyApp.Shop.Product
    |> Ash.Query.limit(100)
    |> Ash.read!()
    |> Enum.each(fn product ->
      Enum.each([:en, :es, :fr], fn locale ->
        AshPhoenixTranslations.translate(product, locale)
      end)
    end)

    # Warm category translations
    MyApp.Shop.Category
    |> Ash.Query.limit(50)
    |> Ash.read!()
    |> Enum.each(fn category ->
      Enum.each([:en, :es, :fr], fn locale ->
        AshPhoenixTranslations.translate(category, locale)
      end)
    end)
  end
end
```

---

## Policy Configuration

### View Policies

Control who can read translations.

```elixir
translations do
  translatable_attribute :name, :string do
    locales [:en, :es, :fr]
  end

  backend :database

  # Anyone can view translations
  policy view: :public
end
```

### Edit Policies

Control who can update translations.

```elixir
translations do
  translatable_attribute :name, :string do
    locales [:en, :es, :fr]
  end

  backend :database

  # Only admins can edit translations
  policy view: :public, edit: :admin
end
```

### Custom Policies

Implement complex authorization logic.

```elixir
translations do
  translatable_attribute :name, :string do
    locales [:en, :es, :fr]
  end

  backend :database

  # Custom policy checks
  policy view: :custom_view_check, edit: :custom_edit_check
end

# In resource
policies do
  policy action(:update_translation) do
    authorize_if AshPhoenixTranslations.Checks.CanEditTranslations
  end
end

# Custom check module
defmodule MyApp.Checks.CanEditTranslations do
  use Ash.Policy.Check

  def match?(actor, %{action: :update_translation}, _opts) do
    # Check if actor has translator role
    actor.roles
    |> Enum.any?(&(&1.name in ["admin", "translator"]))
  end
end
```

### Per-Locale Policies

Different permissions per locale.

```elixir
defmodule MyApp.Shop.Product do
  use Ash.Resource,
    extensions: [AshPhoenixTranslations]

  translations do
    translatable_attribute :name, :string do
      locales [:en, :es, :fr, :de]
    end

    backend :database
    policy view: :public, edit: :custom_locale_policy
  end

  policies do
    policy action(:update_translation) do
      authorize_if MyApp.Checks.LocaleEditPermission
    end
  end
end

defmodule MyApp.Checks.LocaleEditPermission do
  use Ash.Policy.Check

  def match?(actor, context, _opts) do
    locale = get_in(context, [:changeset, :arguments, :locale])

    case {actor.role, locale} do
      {"admin", _} -> true
      {"translator_es", :es} -> true
      {"translator_fr", :fr} -> true
      {"translator_de", :de} -> true
      _ -> false
    end
  end
end
```

---

## Phoenix Integration

### Router Configuration

```elixir
# lib/my_app_web/router.ex
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {MyAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers

    # Translation plugs
    plug MyAppWeb.Plugs.SetLocale
    plug MyAppWeb.Plugs.LoadTranslations
  end

  # ... routes ...
end
```

### SetLocale Plug

```elixir
# lib/my_app_web/plugs/set_locale.ex
defmodule MyAppWeb.Plugs.SetLocale do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    locale = determine_locale(conn)

    # Set Gettext locale
    Gettext.put_locale(MyApp.Gettext, locale)

    # Store in assigns for views/templates
    assign(conn, :locale, String.to_atom(locale))
  end

  defp determine_locale(conn) do
    # Priority: params > session > user > header > default
    conn.params["locale"] ||
      get_session(conn, :locale) ||
      get_user_locale(conn) ||
      parse_accept_language(conn) ||
      "en"
  end

  defp get_user_locale(conn) do
    case conn.assigns[:current_user] do
      %{locale: locale} when not is_nil(locale) -> locale
      _ -> nil
    end
  end

  defp parse_accept_language(conn) do
    case get_req_header(conn, "accept-language") do
      [value | _] ->
        value
        |> String.split(",")
        |> List.first()
        |> String.split(";")
        |> List.first()
        |> String.split("-")
        |> List.first()
        |> String.downcase()

      _ ->
        nil
    end
  end
end
```

### LoadTranslations Plug

```elixir
# lib/my_app_web/plugs/load_translations.ex
defmodule MyAppWeb.Plugs.LoadTranslations do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    locale = conn.assigns[:locale] || :en

    # Preload common translations
    translations = %{
      nav: load_nav_translations(locale),
      footer: load_footer_translations(locale),
      common: load_common_translations(locale)
    }

    assign(conn, :translations, translations)
  end

  defp load_nav_translations(locale) do
    %{
      home: Gettext.dgettext(MyApp.Gettext, "nav", "home", locale: locale),
      products: Gettext.dgettext(MyApp.Gettext, "nav", "products", locale: locale),
      about: Gettext.dgettext(MyApp.Gettext, "nav", "about", locale: locale),
      contact: Gettext.dgettext(MyApp.Gettext, "nav", "contact", locale: locale)
    }
  end

  defp load_footer_translations(locale) do
    %{
      copyright: Gettext.dgettext(MyApp.Gettext, "footer", "copyright", locale: locale),
      privacy: Gettext.dgettext(MyApp.Gettext, "footer", "privacy", locale: locale),
      terms: Gettext.dgettext(MyApp.Gettext, "footer", "terms", locale: locale)
    }
  end

  defp load_common_translations(locale) do
    %{
      save: Gettext.dgettext(MyApp.Gettext, "common", "save", locale: locale),
      cancel: Gettext.dgettext(MyApp.Gettext, "common", "cancel", locale: locale),
      delete: Gettext.dgettext(MyApp.Gettext, "common", "delete", locale: locale),
      edit: Gettext.dgettext(MyApp.Gettext, "common", "edit", locale: locale)
    }
  end
end
```

### Controller Helpers

```elixir
# lib/my_app_web/controllers/product_controller.ex
defmodule MyAppWeb.ProductController do
  use MyAppWeb, :controller
  import AshPhoenixTranslations.Helpers

  def show(conn, %{"id" => id}) do
    locale = conn.assigns.locale

    product =
      MyApp.Shop.Product
      |> Ash.get!(id)
      |> translate(locale)  # Helper from AshPhoenixTranslations.Helpers

    render(conn, :show, product: product)
  end

  def index(conn, _params) do
    locale = conn.assigns.locale

    products =
      MyApp.Shop.Product
      |> Ash.read!()
      |> translate_all(locale)  # Batch translation helper

    render(conn, :index, products: products)
  end
end
```

### LiveView Configuration

```elixir
# lib/my_app_web/live/product_live/show.ex
defmodule MyAppWeb.ProductLive.Show do
  use MyAppWeb, :live_view
  import AshPhoenixTranslations.Helpers

  def mount(%{"id" => id}, _session, socket) do
    product = Ash.get!(MyApp.Shop.Product, id)
    locale = get_connect_params(socket)["locale"] || :en

    socket =
      socket
      |> assign(:product, product)
      |> assign(:locale, locale)
      |> assign(:translated_product, translate(product, locale))

    {:ok, socket}
  end

  def handle_event("change_locale", %{"locale" => locale}, socket) do
    locale_atom = String.to_existing_atom(locale)

    socket =
      socket
      |> assign(:locale, locale_atom)
      |> assign(:translated_product, translate(socket.assigns.product, locale_atom))

    {:noreply, socket}
  end
end
```

---

## Environment-Specific Configuration

### Development Environment

```elixir
# config/dev.exs
import Config

# Gettext configuration
config :my_app, MyApp.Gettext,
  default_locale: "en",
  locales: ~w(en es fr)  # Limited locales for faster development

# Cache configuration
config :ash_phoenix_translations, AshPhoenixTranslations.Cache,
  ttl: 60,               # 1 minute cache in dev
  max_size: 1_000,
  cleanup_interval: 60

# Enable verbose logging
config :logger, level: :debug

# Disable audit in development
config :ash_phoenix_translations,
  audit_changes: false
```

### Test Environment

```elixir
# config/test.exs
import Config

# Disable caching in tests
config :ash_phoenix_translations, AshPhoenixTranslations.Cache,
  enabled: false

# Use minimal locales in tests
config :my_app, MyApp.Gettext,
  default_locale: "en",
  locales: ~w(en es)

# Disable audit in tests
config :ash_phoenix_translations,
  audit_changes: false

# Silence logs
config :logger, level: :warning
```

### Production Environment

```elixir
# config/prod.exs
import Config

# All supported locales
config :my_app, MyApp.Gettext,
  default_locale: "en",
  locales: ~w(en es fr de ja zh pt ru ar)

# Aggressive caching in production
config :ash_phoenix_translations, AshPhoenixTranslations.Cache,
  ttl: 7200,              # 2 hours
  max_size: 50_000,
  cleanup_interval: 300   # 5 minutes

# Enable audit trail
config :ash_phoenix_translations,
  audit_changes: true

# Production logging
config :logger, level: :info
```

### Runtime Configuration

```elixir
# config/runtime.exs
import Config

if config_env() == :prod do
  # Get configuration from environment variables
  cache_ttl =
    System.get_env("TRANSLATION_CACHE_TTL", "7200")
    |> String.to_integer()

  max_cache_size =
    System.get_env("TRANSLATION_CACHE_MAX_SIZE", "50000")
    |> String.to_integer()

  config :ash_phoenix_translations, AshPhoenixTranslations.Cache,
    ttl: cache_ttl,
    max_size: max_cache_size

  # Dynamic locale configuration
  supported_locales =
    System.get_env("SUPPORTED_LOCALES", "en,es,fr")
    |> String.split(",")
    |> Enum.map(&String.trim/1)

  config :my_app, MyApp.Gettext,
    locales: supported_locales
end
```

---

## Advanced Configuration

### Custom Fallback Chains

```elixir
# config/config.exs
config :ash_phoenix_translations,
  fallback_chain: [
    # Regional variants fall back to base language
    en_GB: [:en_US, :en],
    en_AU: [:en_GB, :en_US, :en],
    es_MX: [:es_ES, :es],
    es_AR: [:es_ES, :es],
    pt_BR: [:pt_PT, :pt],

    # Asian languages fall back to English
    ja: [:en],
    zh: [:en],
    ko: [:en],

    # European languages cross-fallback
    fr: [:en],
    de: [:en],
    it: [:es, :fr, :en],

    # Complex fallback chains
    ru: [:en],
    ar: [:en],
    hi: [:en]
  ]
```

### Custom Storage Field Names

```elixir
# Override storage field naming convention
defmodule MyApp.Shop.Product do
  use Ash.Resource,
    extensions: [AshPhoenixTranslations]

  translations do
    translatable_attribute :name, :string do
      locales [:en, :es, :fr]
      storage_field :name_i18n  # Custom field name instead of name_translations
    end

    backend :database
  end
end
```

### Custom Gettext Domains

```elixir
# Use different Gettext domains per resource type
defmodule MyApp.Shop.Product do
  use Ash.Resource,
    extensions: [AshPhoenixTranslations]

  translations do
    translatable_attribute :name, :string do
      locales [:en, :es, :fr]
    end

    backend :gettext
    gettext_domain "products"  # Custom domain
  end
end

defmodule MyApp.Shop.Category do
  use Ash.Resource,
    extensions: [AshPhoenixTranslations]

  translations do
    translatable_attribute :name, :string do
      locales [:en, :es, :fr]
    end

    backend :gettext
    gettext_domain "categories"  # Different domain
  end
end
```

### Conditional Backend Selection

```elixir
# Use different backends based on environment
defmodule MyApp.Shop.Product do
  use Ash.Resource,
    extensions: [AshPhoenixTranslations]

  @backend if Mix.env() == :prod, do: :database, else: :gettext

  translations do
    translatable_attribute :name, :string do
      locales [:en, :es, :fr]
    end

    backend @backend
  end
end
```

---

## Performance Tuning

### Database Query Optimization

```elixir
# Eager load translations with resources
defmodule MyAppWeb.ProductController do
  def index(conn, _params) do
    locale = conn.assigns.locale

    # Bad: N+1 queries
    products =
      MyApp.Shop.Product
      |> Ash.read!()
      |> Enum.map(&translate(&1, locale))

    # Good: Batch translation with single query
    products =
      MyApp.Shop.Product
      |> Ash.read!()
      |> translate_all(locale)  # Single efficient query

    render(conn, :index, products: products)
  end
end
```

### Cache Hit Rate Monitoring

```elixir
# Monitor cache performance
defmodule MyApp.CacheMonitor do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    # Check cache stats every minute
    schedule_check()
    {:ok, state}
  end

  def handle_info(:check_stats, state) do
    stats = AshPhoenixTranslations.Cache.stats()

    if stats.hit_rate < 0.7 do
      # Log warning if hit rate below 70%
      require Logger
      Logger.warning("Translation cache hit rate low: \#{stats.hit_rate * 100}%")
    end

    schedule_check()
    {:noreply, state}
  end

  defp schedule_check do
    Process.send_after(self(), :check_stats, 60_000)  # 1 minute
  end
end

# Add to supervision tree
children = [
  # ...
  MyApp.CacheMonitor
]
```

### Preloading Strategies

```elixir
# Preload translations at application startup
defmodule MyApp.TranslationPreloader do
  def preload_critical_translations do
    # Preload top 100 products
    critical_products =
      MyApp.Shop.Product
      |> Ash.Query.sort(views: :desc)
      |> Ash.Query.limit(100)
      |> Ash.read!()

    # Warm cache for all supported locales
    Enum.each([:en, :es, :fr, :de], fn locale ->
      AshPhoenixTranslations.translate_all(critical_products, locale)
    end)

    # Preload categories
    categories = Ash.read!(MyApp.Shop.Category)

    Enum.each([:en, :es, :fr, :de], fn locale ->
      AshPhoenixTranslations.translate_all(categories, locale)
    end)
  end
end

# Call during application startup
def start(_type, _args) do
  children = [
    # ... other children ...
    {Task, fn -> MyApp.TranslationPreloader.preload_critical_translations() end}
  ]

  Supervisor.start_link(children, strategy: :one_for_one)
end
```

### Batch Translation Updates

```elixir
# Efficient batch updates
defmodule MyApp.BatchTranslationUpdater do
  def update_translations(updates) do
    # Group updates by resource
    grouped = Enum.group_by(updates, & &1.resource_id)

    # Batch update per resource
    Enum.each(grouped, fn {resource_id, translations} ->
      resource = Ash.get!(MyApp.Shop.Product, resource_id)

      # Build translation map
      translation_map =
        Enum.reduce(translations, %{}, fn %{locale: locale, field: field, value: value}, acc ->
          field_key = :"#{field}_translations"
          existing = Map.get(acc, field_key, resource[field_key] || %{})
          Map.put(acc, field_key, Map.put(existing, locale, value))
        end)

      # Single update with all translations
      resource
      |> Ash.Changeset.for_update(:update, translation_map)
      |> Ash.update!()

      # Invalidate cache
      AshPhoenixTranslations.Cache.invalidate_resource(MyApp.Shop.Product, resource_id)
    end)
  end
end
```

---

## Troubleshooting

### Common Configuration Issues

#### Issue: Translations Not Showing

**Symptoms**: Translation fields return `nil` or original text.

**Solutions**:
```elixir
# 1. Check locale is set correctly
IO.inspect(Gettext.get_locale(MyApp.Gettext))  # Should return current locale

# 2. Verify translations exist
product = Ash.get!(MyApp.Shop.Product, id)
IO.inspect(product.name_translations)  # Database backend
# Should show: %{en: "...", es: "...", fr: "..."}

# 3. Check resource configuration
attrs = AshPhoenixTranslations.Info.translatable_attributes(MyApp.Shop.Product)
IO.inspect(attrs)  # Should list translatable attributes

# 4. Verify backend is configured
backend = AshPhoenixTranslations.Info.backend(MyApp.Shop.Product)
IO.inspect(backend)  # Should be :database or :gettext
```

#### Issue: Cache Not Working

**Symptoms**: Performance issues, repeated database queries.

**Solutions**:
```elixir
# 1. Verify cache is enabled
config = Application.get_env(:ash_phoenix_translations, AshPhoenixTranslations.Cache)
IO.inspect(config[:enabled])  # Should be true

# 2. Check cache stats
stats = AshPhoenixTranslations.Cache.stats()
IO.inspect(stats)
# %{hits: X, misses: Y, hit_rate: Z, size: N}

# 3. Verify cache TTL is set
ttl = AshPhoenixTranslations.Info.cache_ttl(MyApp.Shop.Product)
IO.inspect(ttl)  # Should be > 0

# 4. Check if cache GenServer is running
Process.whereis(AshPhoenixTranslations.Cache) != nil  # Should be true
```

#### Issue: Gettext Files Not Found

**Symptoms**: Gettext translations missing, errors about missing .po files.

**Solutions**:
```bash
# 1. Generate POT template
mix ash_phoenix_translations.extract --domain MyApp.Shop --format pot

# 2. Create PO files for each locale
cp priv/gettext/default.pot priv/gettext/es/LC_MESSAGES/default.po
cp priv/gettext/default.pot priv/gettext/fr/LC_MESSAGES/default.po

# 3. Compile Gettext
mix gettext.merge priv/gettext --locale es
mix gettext.merge priv/gettext --locale fr

# 4. Verify directory structure
tree priv/gettext
# Should show:
# priv/gettext/
# ├── default.pot
# ├── en/LC_MESSAGES/default.po
# ├── es/LC_MESSAGES/default.po
# └── fr/LC_MESSAGES/default.po
```

#### Issue: Policy Violations

**Symptoms**: Authorization errors when updating translations.

**Solutions**:
```elixir
# 1. Check actor has required role
actor = %{id: user_id, roles: ["translator"]}

# 2. Use actor in update
product
|> Ash.Changeset.for_update(:update_translation, %{
  locale: :es,
  field: :name,
  value: "Nombre"
})
|> Ash.update(actor: actor)  # Pass actor for authorization

# 3. Verify policy configuration
policies = AshPhoenixTranslations.Info.policies(MyApp.Shop.Product)
IO.inspect(policies)
```

### Debug Mode

Enable verbose logging for troubleshooting:

```elixir
# config/dev.exs
config :logger, level: :debug

# Enable query logging
config :ash,
  log_level: :debug

# Enable translation debug logs
config :ash_phoenix_translations,
  debug: true
```

### Testing Configuration

```elixir
# test/support/translation_test_helpers.ex
defmodule MyApp.TranslationTestHelpers do
  def assert_translation_configured(resource, field) do
    attrs = AshPhoenixTranslations.Info.translatable_attributes(resource)
    assert Enum.any?(attrs, &(&1.name == field))
  end

  def assert_locales_supported(resource, expected_locales) do
    locales = AshPhoenixTranslations.Info.supported_locales(resource)
    assert Enum.sort(locales) == Enum.sort(expected_locales)
  end

  def assert_backend(resource, expected_backend) do
    backend = AshPhoenixTranslations.Info.backend(resource)
    assert backend == expected_backend
  end
end
```

---

## Configuration Checklist

### Initial Setup

- [ ] Choose backend (database or gettext)
- [ ] Define supported locales
- [ ] Configure translatable attributes
- [ ] Set cache TTL
- [ ] Configure policies (view/edit)
- [ ] Add Phoenix plugs (SetLocale, LoadTranslations)

### Production Readiness

- [ ] Enable audit trail if using database backend
- [ ] Configure cache warming for critical resources
- [ ] Set up cache monitoring
- [ ] Configure environment-specific settings
- [ ] Test fallback chains
- [ ] Verify policy authorization
- [ ] Set up locale switching UI
- [ ] Configure runtime environment variables

### Performance Optimization

- [ ] Enable caching with appropriate TTL
- [ ] Implement cache warming strategy
- [ ] Monitor cache hit rate
- [ ] Use batch translation updates
- [ ] Preload translations in controllers
- [ ] Configure cleanup intervals

### Security Hardening

- [ ] Configure strict policies
- [ ] Validate locale input (use LocaleValidator)
- [ ] Sanitize translation content
- [ ] Enable audit logging
- [ ] Implement rate limiting for translation updates
- [ ] Use atom exhaustion prevention (String.to_existing_atom/1)

---

For additional examples, see [EXAMPLES.md](EXAMPLES.md).

For detailed API documentation, run `mix docs` and open `doc/index.html`.
