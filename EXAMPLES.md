# AshPhoenixTranslations Examples

Comprehensive real-world examples demonstrating translation patterns and best practices.

## Table of Contents

- [E-Commerce Scenarios](#e-commerce-scenarios)
- [Content Management System](#content-management-system)
- [Multi-Tenant Applications](#multi-tenant-applications)
- [Performance Optimization](#performance-optimization)
- [Security Patterns](#security-patterns)
- [Backend Integration](#backend-integration)
- [LiveView Integration](#liveview-integration)
- [GraphQL Integration](#graphql-integration)
- [Migration Strategies](#migration-strategies)
- [Testing Patterns](#testing-patterns)

---

## E-Commerce Scenarios

### Basic Product Catalog

```elixir
defmodule MyApp.Shop.Product do
  use Ash.Resource,
    domain: MyApp.Shop,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshPhoenixTranslations]

  postgres do
    table "products"
    repo MyApp.Repo
  end

  translations do
    translatable_attribute :name, :string do
      locales [:en, :es, :fr, :de]
      required [:en]
      validation max_length: 200
    end

    translatable_attribute :description, :text do
      locales [:en, :es, :fr, :de]
      fallback :en
      markdown true
    end

    translatable_attribute :short_description, :string do
      locales [:en, :es, :fr, :de]
      fallback :en
      validation max_length: 500
    end

    backend :database
    cache_ttl 7200  # 2 hours
    audit_changes true
  end

  attributes do
    uuid_primary_key :id

    attribute :sku, :string do
      allow_nil? false
    end

    attribute :price, :decimal do
      allow_nil? false
    end

    attribute :stock_quantity, :integer do
      default 0
    end

    timestamps()
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:sku, :price, :stock_quantity, :name_translations, :description_translations]
    end

    update :update do
      accept [:sku, :price, :stock_quantity, :name_translations, :description_translations]
    end
  end
end
```

### Creating Products with Translations

```elixir
# Create product with multiple translations
{:ok, product} =
  MyApp.Shop.Product
  |> Ash.Changeset.for_create(:create, %{
    sku: "TSHIRT-001",
    price: Decimal.new("29.99"),
    stock_quantity: 100,
    name_translations: %{
      en: "Classic Cotton T-Shirt",
      es: "Camiseta de Algodón Clásica",
      fr: "T-Shirt en Coton Classique",
      de: "Klassisches Baumwoll-T-Shirt"
    },
    description_translations: %{
      en: "Comfortable 100% cotton t-shirt. Perfect for everyday wear.",
      es: "Camiseta cómoda de 100% algodón. Perfecta para el uso diario.",
      fr: "T-shirt confortable en 100% coton. Parfait pour un usage quotidien.",
      de: "Bequemes T-Shirt aus 100% Baumwolle. Perfekt für den täglichen Gebrauch."
    }
  })
  |> Ash.create()

# Access translated product name
AshPhoenixTranslations.translate(product, :en)
# => %Product{name: "Classic Cotton T-Shirt", ...}
```

### Product Categories with Hierarchy

```elixir
defmodule MyApp.Shop.Category do
  use Ash.Resource,
    domain: MyApp.Shop,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshPhoenixTranslations]

  translations do
    translatable_attribute :name, :string do
      locales [:en, :es, :fr, :de]
      required [:en]
    end

    translatable_attribute :description, :text do
      locales [:en, :es, :fr, :de]
      fallback :en
    end

    backend :database
    cache_ttl 14400  # 4 hours (categories change rarely)
  end

  attributes do
    uuid_primary_key :id
    attribute :slug, :string
    timestamps()
  end

  relationships do
    belongs_to :parent, MyApp.Shop.Category
    has_many :children, MyApp.Shop.Category, destination_attribute: :parent_id
    has_many :products, MyApp.Shop.Product
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end
```

---

## Content Management System

### Blog Posts with SEO

```elixir
defmodule MyApp.CMS.Post do
  use Ash.Resource,
    domain: MyApp.CMS,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshPhoenixTranslations]

  translations do
    translatable_attribute :title, :string do
      locales [:en, :es, :fr]
      required [:en]
      validation max_length: 150
    end

    translatable_attribute :content, :text do
      locales [:en, :es, :fr]
      required [:en]
      markdown true
    end

    translatable_attribute :excerpt, :string do
      locales [:en, :es, :fr]
      fallback :en
      validation max_length: 300
    end

    translatable_attribute :meta_title, :string do
      locales [:en, :es, :fr]
      fallback :en
      validation max_length: 60
    end

    translatable_attribute :meta_description, :string do
      locales [:en, :es, :fr]
      fallback :en
      validation max_length: 160
    end

    backend :database
    cache_ttl 3600
    audit_changes true
  end

  attributes do
    uuid_primary_key :id

    attribute :slug, :string do
      allow_nil? false
    end

    attribute :published_at, :utc_datetime
    attribute :status, :atom, constraints: [one_of: [:draft, :published, :archived]]

    timestamps()
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    read :published do
      filter expr(status == :published and not is_nil(published_at))
    end
  end
end
```

### Multi-Language Blog Workflow

```elixir
defmodule MyApp.CMS.Workflows do
  @doc """
  Creates a blog post with translations in stages.
  """
  def create_post_workflow do
    # Stage 1: Create draft in English
    {:ok, post} =
      MyApp.CMS.Post
      |> Ash.Changeset.for_create(:create, %{
        slug: "introducing-new-features",
        status: :draft,
        title_translations: %{en: "Introducing New Features"},
        content_translations: %{en: "# New Features\n\nWe're excited to announce..."}
      })
      |> Ash.create()

    # Stage 2: Add Spanish translation
    {:ok, post} =
      post
      |> Ash.Changeset.for_update(:update, %{
        title_translations: %{
          en: "Introducing New Features",
          es: "Presentamos Nuevas Funciones"
        },
        content_translations: %{
          en: "# New Features\n\nWe're excited to announce...",
          es: "# Nuevas Funciones\n\nNos complace anunciar..."
        }
      })
      |> Ash.update()

    # Stage 3: Publish when all translations ready
    {:ok, post} =
      post
      |> Ash.Changeset.for_update(:update, %{
        status: :published,
        published_at: DateTime.utc_now()
      })
      |> Ash.update()

    {:ok, post}
  end

  @doc """
  Validates translation completeness before publishing.
  """
  def validate_before_publish(post, required_locales \\ [:en, :es]) do
    title_translations = post.title_translations || %{}
    content_translations = post.content_translations || %{}

    missing_locales =
      required_locales
      |> Enum.filter(fn locale ->
        is_nil(title_translations[locale]) or is_nil(content_translations[locale])
      end)

    case missing_locales do
      [] -> :ok
      locales -> {:error, "Missing translations for: #{Enum.join(locales, ", ")}"}
    end
  end
end
```

---

## Multi-Tenant Applications

### Tenant-Specific Locale Configuration

```elixir
defmodule MyApp.Accounts.Tenant do
  use Ash.Resource,
    domain: MyApp.Accounts,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    attribute :name, :string
    attribute :supported_locales, {:array, :atom}, default: [:en]
    attribute :default_locale, :atom, default: :en
    timestamps()
  end
end

defmodule MyApp.Multitenancy.LocaleResolver do
  @doc """
  Resolves locale based on tenant configuration.
  """
  def resolve_locale(conn, tenant) do
    # 1. Check user preference
    user_locale = get_user_locale(conn)

    # 2. Check tenant supported locales
    if user_locale in tenant.supported_locales do
      user_locale
    else
      # 3. Fall back to tenant default
      tenant.default_locale
    end
  end

  defp get_user_locale(conn) do
    conn.assigns[:current_user]
    |> case do
      %{preferred_locale: locale} when not is_nil(locale) -> locale
      _ -> nil
    end
  end
end
```

### Per-Tenant Translation Strategy

```elixir
defmodule MyApp.Multitenancy.TranslationPolicy do
  @doc """
  Determines backend based on tenant tier.
  """
  def backend_for_tenant(tenant) do
    case tenant.subscription_tier do
      :enterprise -> :database  # Full translation management
      :professional -> :database
      :basic -> :gettext  # Static translations only
      _ -> :gettext
    end
  end

  @doc """
  Configures cache TTL based on tenant plan.
  """
  def cache_ttl_for_tenant(tenant) do
    case tenant.subscription_tier do
      :enterprise -> 3600  # 1 hour
      :professional -> 7200  # 2 hours
      _ -> 14400  # 4 hours
    end
  end
end
```

---

## Performance Optimization

### Cache Warming Strategy

```elixir
defmodule MyApp.Translations.CacheWarmer do
  alias AshPhoenixTranslations.Cache

  @doc """
  Warms cache for frequently accessed products.
  """
  def warm_product_cache do
    # Get top 100 most viewed products
    popular_products =
      MyApp.Shop.Product
      |> Ash.Query.sort(views: :desc)
      |> Ash.Query.limit(100)
      |> Ash.read!()

    # Pre-load translations for all supported locales
    locales = [:en, :es, :fr, :de]
    fields = [:name, :description, :short_description]

    Enum.each(popular_products, fn product ->
      Enum.each(locales, fn locale ->
        Enum.each(fields, fn field ->
          # This will cache the translation
          key = {MyApp.Shop.Product, product.id, field, locale}
          value = Map.get(product, :"#{field}_translations")[locale]

          if value do
            Cache.put(key, value)
          end
        end)
      end)
    end)
  end

  @doc """
  Scheduled cache warming (run via Quantum or similar).
  """
  def schedule_cache_warming do
    # Warm cache every hour
    :timer.apply_interval(3_600_000, __MODULE__, :warm_product_cache, [])
  end
end
```

### Bulk Translation Loading

```elixir
defmodule MyApp.Translations.BulkLoader do
  @doc """
  Efficiently loads translations for multiple resources.
  """
  def preload_translations(resources, locale) do
    # Batch translate all resources at once
    AshPhoenixTranslations.translate_all(resources, locale)
  end

  @doc """
  Loads product catalog with translations.
  """
  def load_catalog_page(page, per_page, locale) do
    MyApp.Shop.Product
    |> Ash.Query.offset((page - 1) * per_page)
    |> Ash.Query.limit(per_page)
    |> Ash.read!()
    |> preload_translations(locale)
  end
end
```

---

## Security Patterns

### Input Validation

```elixir
defmodule MyApp.Translations.Security do
  @doc """
  Validates locale before processing.
  """
  def validate_locale(locale_string) when is_binary(locale_string) do
    AshPhoenixTranslations.LocaleValidator.validate_locale(locale_string)
  end

  @doc """
  Sanitizes translation content to prevent XSS.
  """
  def sanitize_translation(content, field_type) do
    case field_type do
      :markdown ->
        # Allow safe markdown, strip dangerous HTML
        HtmlSanitizeEx.markdown_html(content)

      :html ->
        # Strict HTML sanitization
        HtmlSanitizeEx.basic_html(content)

      _ ->
        # Plain text - escape all HTML
        Phoenix.HTML.html_escape(content)
        |> Phoenix.HTML.safe_to_string()
    end
  end

  @doc """
  Validates translation length limits.
  """
  def validate_translation_length(translations, field, max_length) do
    Enum.all?(translations, fn {_locale, value} ->
      String.length(value) <= max_length
    end)
  end
end
```

### Rate Limiting Translation Updates

```elixir
defmodule MyApp.Translations.RateLimiter do
  use GenServer

  @doc """
  Rate limits translation updates per user.
  """
  def check_rate_limit(user_id, action) do
    GenServer.call(__MODULE__, {:check_limit, user_id, action})
  end

  def handle_call({:check_limit, user_id, action}, _from, state) do
    key = {user_id, action}
    now = System.system_time(:second)

    case Map.get(state, key) do
      nil ->
        # First request
        {:reply, :ok, Map.put(state, key, {1, now})}

      {count, timestamp} when now - timestamp > 60 ->
        # Window expired, reset
        {:reply, :ok, Map.put(state, key, {1, now})}

      {count, timestamp} when count < 10 ->
        # Within limit
        {:reply, :ok, Map.put(state, key, {count + 1, timestamp})}

      _ ->
        # Rate limited
        {:reply, {:error, :rate_limited}, state}
    end
  end
end
```

---

## Backend Integration

### Database Backend Setup

```elixir
# Migration for translation storage
defmodule MyApp.Repo.Migrations.AddTranslationSupport do
  use Ecto.Migration

  def change do
    # Products table with JSONB translation columns
    alter table(:products) do
      add :name_translations, :map, default: %{}
      add :description_translations, :map, default: %{}
    end

    # Add GIN indexes for JSONB columns (PostgreSQL)
    create index(:products, [:name_translations], using: :gin)
    create index(:products, [:description_translations], using: :gin)
  end
end
```

### Gettext Backend Setup

```elixir
# config/config.exs
config :my_app, MyAppWeb.Gettext,
  locales: ~w(en es fr de),
  default_locale: "en"

config :ash_phoenix_translations,
  default_backend: :gettext,
  default_locales: [:en, :es, :fr, :de]
```

```bash
# Extract translations to POT files
mix ash_phoenix_translations.extract

# Generate PO files for each locale
mix ash_phoenix_translations.extract --locales en,es,fr,de --format both

# Merge with existing translations
mix gettext.merge priv/gettext

# Compile .po to .mo files
mix compile.gettext
```

### Hybrid Backend Strategy

```elixir
defmodule MyApp.Shop.Product do
  # User-editable content → Database
  translations do
    translatable_attribute :name, :string do
      locales [:en, :es, :fr]
      backend :database
    end
  end
end

defmodule MyApp.CMS.PageTemplate do
  # Static UI content → Gettext
  translations do
    translatable_attribute :title, :string do
      locales [:en, :es, :fr]
      backend :gettext
    end
  end
end
```

---

## LiveView Integration

### Locale Switcher Component

```elixir
defmodule MyAppWeb.Components.LocaleSwitcher do
  use Phoenix.Component
  import AshPhoenixTranslations.Helpers

  attr :current_locale, :atom, required: true
  attr :available_locales, :list, default: [:en, :es, :fr, :de]

  def locale_switcher(assigns) do
    ~H"""
    <div class="locale-switcher">
      <select
        phx-change="change_locale"
        class="locale-select"
      >
        <%= for locale <- @available_locales do %>
          <option value={locale} selected={locale == @current_locale}>
            <%= locale_name(locale) %>
          </option>
        <% end %>
      </select>
    </div>
    """
  end

  defp locale_name(:en), do: "English"
  defp locale_name(:es), do: "Español"
  defp locale_name(:fr), do: "Français"
  defp locale_name(:de), do: "Deutsch"
end
```

### LiveView with Translation State

```elixir
defmodule MyAppWeb.ProductLive.Index do
  use MyAppWeb, :live_view
  import AshPhoenixTranslations.Helpers

  def mount(_params, session, socket) do
    locale = get_locale_from_session(session)

    products =
      MyApp.Shop.Product
      |> Ash.read!()
      |> AshPhoenixTranslations.translate_all(locale)

    {:ok, assign(socket, products: products, locale: locale)}
  end

  def handle_event("change_locale", %{"value" => locale}, socket) do
    locale_atom = String.to_existing_atom(locale)

    # Re-translate all products
    products = AshPhoenixTranslations.translate_all(socket.assigns.products, locale_atom)

    {:noreply, assign(socket, products: products, locale: locale_atom)}
  end

  def render(assigns) do
    ~H"""
    <.locale_switcher current_locale={@locale} />

    <div class="products">
      <%= for product <- @products do %>
        <div class="product-card">
          <h3><%= product.name %></h3>
          <p><%= product.description %></p>
          <span class="price"><%= product.price %></span>
        </div>
      <% end %>
    </div>
    """
  end
end
```

---

## GraphQL Integration

### GraphQL Schema with Translations

```elixir
defmodule MyAppWeb.Schema do
  use Absinthe.Schema

  import_types MyAppWeb.Schema.ProductTypes

  query do
    field :products, list_of(:product) do
      arg :locale, :locale, default_value: :en

      resolve fn %{locale: locale}, _context ->
        products =
          MyApp.Shop.Product
          |> Ash.read!()
          |> AshPhoenixTranslations.translate_all(locale)

        {:ok, products}
      end
    end
  end

  enum :locale do
    value :en
    value :es
    value :fr
    value :de
  end
end

defmodule MyAppWeb.Schema.ProductTypes do
  use Absinthe.Schema.Notation

  object :product do
    field :id, non_null(:id)
    field :sku, non_null(:string)
    field :name, non_null(:string)  # Translated based on locale arg
    field :description, :string
    field :price, non_null(:decimal)
  end
end
```

### GraphQL Query Examples

```graphql
# Query products in Spanish
query {
  products(locale: ES) {
    id
    sku
    name
    description
    price
  }
}

# Query with fallback handling
query {
  products(locale: FR) {
    id
    name  # Falls back to :en if French translation missing
  }
}
```

---

## Migration Strategies

### Migrating from Gettext to Database

```elixir
defmodule MyApp.Migrations.GettextToDatabase do
  @doc """
  Migrates translations from Gettext .po files to database.
  """
  def migrate_to_database do
    locales = [:en, :es, :fr]

    MyApp.Shop.Product
    |> Ash.read!()
    |> Enum.each(fn product ->
      translations =
        locales
        |> Enum.reduce(%{}, fn locale, acc ->
          # Read translation from Gettext
          translation =
            Gettext.gettext(
              MyAppWeb.Gettext,
              "product.#{product.id}.name",
              locale: locale
            )

          Map.put(acc, locale, translation)
        end)

      # Update product with database translations
      product
      |> Ash.Changeset.for_update(:update, %{name_translations: translations})
      |> Ash.update!()
    end)
  end
end
```

### Gradual Migration Pattern

```elixir
defmodule MyApp.Translations.GradualMigration do
  @doc """
  Supports both backends during migration period.
  """
  def get_translation(resource, field, locale) do
    # Try database first
    case get_database_translation(resource, field, locale) do
      nil ->
        # Fall back to Gettext
        get_gettext_translation(resource, field, locale)

      translation ->
        translation
    end
  end

  defp get_database_translation(resource, field, locale) do
    translations = Map.get(resource, :"#{field}_translations") || %{}
    Map.get(translations, locale)
  end

  defp get_gettext_translation(resource, field, locale) do
    key = "#{resource.__struct__}.#{resource.id}.#{field}"
    Gettext.gettext(MyAppWeb.Gettext, key, locale: locale)
  end
end
```

---

## Testing Patterns

### Testing Translated Resources

```elixir
defmodule MyApp.Shop.ProductTest do
  use MyApp.DataCase

  describe "translations" do
    test "creates product with multiple translations" do
      {:ok, product} =
        MyApp.Shop.Product
        |> Ash.Changeset.for_create(:create, %{
          sku: "TEST-001",
          price: Decimal.new("19.99"),
          name_translations: %{
            en: "Test Product",
            es: "Producto de Prueba"
          }
        })
        |> Ash.create()

      # Verify English translation
      translated_en = AshPhoenixTranslations.translate(product, :en)
      assert translated_en.name == "Test Product"

      # Verify Spanish translation
      translated_es = AshPhoenixTranslations.translate(product, :es)
      assert translated_es.name == "Producto de Prueba"
    end

    test "falls back to default locale when translation missing" do
      {:ok, product} =
        MyApp.Shop.Product
        |> Ash.Changeset.for_create(:create, %{
          sku: "TEST-002",
          price: Decimal.new("29.99"),
          description_translations: %{en: "English only"}
        })
        |> Ash.create()

      # French should fall back to English
      translated = AshPhoenixTranslations.translate(product, :fr)
      assert translated.description == "English only"
    end

    test "validates required translations" do
      # English is required
      changeset =
        MyApp.Shop.Product
        |> Ash.Changeset.for_create(:create, %{
          sku: "TEST-003",
          price: Decimal.new("39.99"),
          name_translations: %{es: "Solo Español"}  # Missing required :en
        })

      assert {:error, %Ash.Error.Invalid{}} = Ash.create(changeset)
    end
  end
end
```

### Testing Translation Workflows

```elixir
defmodule MyApp.Translations.WorkflowTest do
  use MyApp.DataCase

  test "complete translation workflow" do
    # 1. Create in English
    {:ok, post} =
      MyApp.CMS.Post
      |> Ash.Changeset.for_create(:create, %{
        slug: "test-post",
        title_translations: %{en: "Test Post"},
        content_translations: %{en: "English content"}
      })
      |> Ash.create()

    # 2. Add Spanish translation
    {:ok, post} =
      post
      |> Ash.Changeset.for_update(:update, %{
        title_translations: Map.put(post.title_translations, :es, "Publicación de Prueba"),
        content_translations: Map.put(post.content_translations, :es, "Contenido en español")
      })
      |> Ash.update()

    # 3. Verify both translations exist
    assert post.title_translations[:en] == "Test Post"
    assert post.title_translations[:es] == "Publicación de Prueba"

    # 4. Test translation retrieval
    en_post = AshPhoenixTranslations.translate(post, :en)
    assert en_post.title == "Test Post"

    es_post = AshPhoenixTranslations.translate(post, :es)
    assert es_post.title == "Publicación de Prueba"
  end
end
```

---

## Additional Resources

- [Main README](README.md) - Installation and quick start
- [CONFIGURATION.md](CONFIGURATION.md) - Detailed configuration guide
- [API Documentation](https://hexdocs.pm/ash_phoenix_translations) - Complete API reference
- [Ash Framework Docs](https://hexdocs.pm/ash) - Ash framework documentation
