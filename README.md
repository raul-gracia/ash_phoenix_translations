# AshPhoenixTranslations

[![CI](https://github.com/raul-gracia/ash_phoenix_translations/actions/workflows/ci.yml/badge.svg)](https://github.com/raul-gracia/ash_phoenix_translations/actions/workflows/ci.yml)
[![Security Audit](https://github.com/raul-gracia/ash_phoenix_translations/actions/workflows/security.yml/badge.svg)](https://github.com/raul-gracia/ash_phoenix_translations/actions/workflows/security.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/ash_phoenix_translations.svg)](https://hex.pm/packages/ash_phoenix_translations)
[![Hex Docs](https://img.shields.io/badge/hex-docs-purple.svg)](https://hexdocs.pm/ash_phoenix_translations)
[![License](https://img.shields.io/hexpm/l/ash_phoenix_translations.svg)](https://github.com/raul-gracia/ash_phoenix_translations/blob/main/LICENSE)

Policy-aware translation extension for [Ash Framework](https://ash-hq.org/) with multi-backend support, optimized for Phoenix applications.

## Features

- 🌍 **Multi-locale Support** - Manage translations for unlimited locales per field
- 🔐 **Policy-aware** - Leverage Ash policies for translation access control
- 💾 **Multiple Storage Backends** - Database (JSONB ✅), Gettext (✅)
- ⚡ **Performance Optimized** - Built-in caching with TTL and invalidation
- 🔄 **LiveView Integration** - Real-time locale switching and updates
- 📦 **Import/Export** - CSV, JSON, and XLIFF format support
- ✅ **Validation** - Built-in translation completeness and quality checks
- 🎨 **Phoenix Helpers** - Template helpers for easy translation rendering
- 📊 **GraphQL Support** - Automatic GraphQL field generation with resolvers
- 🔗 **JSON:API Support** - Full JSON:API integration with locale handling
- 🏗️ **Embedded Schemas** - Translation support for nested and embedded resources  
- 🔍 **Gettext Extraction** - Extract translatable strings to POT files
- 🎯 **Role-based Authorization** - Admin, translator, and user role support
- 📋 **Mix Tasks** - Install, import, export, validate, and extract commands

## Installation

Add `ash_phoenix_translations` to your dependencies:

```elixir
def deps do
  [
    {:ash_phoenix_translations, "~> 1.0.0"}
  ]
end
```

Run the installation task:

```bash
mix ash_phoenix_translations.install
```

This will:
- Add configuration to your `config/config.exs`
- Generate migration files (for database backend)
- Create example resources
- Set up Gettext directories (if using Gettext backend)

## Quick Start

### 1. Add the Extension to Your Resource

```elixir
defmodule MyApp.Product do
  use Ash.Resource,
    extensions: [AshPhoenixTranslations]
  
  translations do
    translatable_attribute :name,
      locales: [:en, :es, :fr],
      required: [:en]
    
    translatable_attribute :description,
      locales: [:en, :es, :fr],
      translate: true  # Auto-translate via calculation
    
    backend :database  # :database | :gettext
    cache_ttl 3600
    audit_changes true
  end
  
  attributes do
    uuid_primary_key :id
    attribute :sku, :string
    timestamps()
  end
  
  actions do
    defaults [:create, :read, :update, :destroy]
  end
end
```

### 2. Configure Your Phoenix Application

Add the plugs to your router:

```elixir
pipeline :browser do
  # ... other plugs
  plug AshPhoenixTranslations.Plugs.SetLocale,
    strategies: [:param, :session, :header],
    fallback: "en"
  plug AshPhoenixTranslations.Plugs.LoadTranslations
end
```

Import helpers in your HTML helpers module:

```elixir
def html do
  quote do
    # ... other imports
    import AshPhoenixTranslations.Helpers
  end
end
```

### 3. Use Translations in Templates

```elixir
# In your templates
<h1><%= t(@product, :name) %></h1>
<p><%= t(@product, :description, locale: "es") %></p>

# With fallback
<%= t(@product, :tagline, fallback: "No tagline available") %>

# Language switcher
<%= language_switcher(@conn, Product) %>

# Translation status badges
<%= translation_status(@product, :description) %>
# Shows: [EN ✓] [ES ✓] [FR ✗]
```

### 4. Manage Translations

```elixir
# Create with translations
{:ok, product} = 
  Product
  |> Ash.Changeset.for_create(:create, %{
    sku: "PROD-001",
    name_translations: %{
      en: "Laptop",
      es: "Portátil",
      fr: "Ordinateur portable"
    },
    description_translations: %{
      en: "High-performance laptop",
      es: "Portátil de alto rendimiento"
    }
  })
  |> Ash.create()

# Update translations
{:ok, updated} = 
  product
  |> Ash.Changeset.for_update(:update, %{
    name_translations: %{
      en: "Gaming Laptop",
      es: "Portátil Gaming"
    }
  })
  |> Ash.update()

# Get translated version
translated = AshPhoenixTranslations.translate(product, :es)
translated.name # => "Portátil Gaming"
translated.description # => "Portátil de alto rendimiento"
```

## LiveView Integration

```elixir
defmodule MyAppWeb.ProductLive do
  use MyAppWeb, :live_view
  use AshPhoenixTranslations.LiveView
  
  def mount(_params, session, socket) do
    socket = 
      socket
      |> assign_locale(session)
      |> assign_translations(:products, Product.list_products!())
    
    {:ok, socket}
  end
  
  def handle_event("change_locale", %{"locale" => locale}, socket) do
    {:noreply, update_locale(socket, locale)}
  end
end
```

In your LiveView template:

```elixir
<.locale_switcher socket={@socket} />

<.translation_field form={@form} field={:name} locales={[:en, :es, :fr]} />

<.translation_progress resource={@product} />

<.translation_preview resource={@product} field={:description} />
```

## Storage Backends

### Database Backend (Default)

Uses JSONB columns for PostgreSQL or JSON for other databases:

```elixir
translations do
  backend :database
  # Stores in name_translations, description_translations columns
  cache_ttl 3600  # Optional caching
  audit_changes true  # Optional audit trail
end
```

**Migration Example:**
```bash
# The install task generates this automatically
mix ash_phoenix_translations.install --backend database
mix ecto.migrate
```

### Gettext Backend

Integrates with Phoenix's built-in Gettext for translation management via .po files:

```elixir
translations do
  backend :gettext
  gettext_module MyAppWeb.Gettext  # Required for Gettext backend
  
  translatable_attribute :name, :string do
    locales [:en, :es, :fr]
  end
end
```

**Gettext Setup:**
```bash
# Install and setup gettext directories
mix ash_phoenix_translations.install --backend gettext

# Extract translatable strings
mix ash_phoenix_translations.extract

# Update .po files
mix gettext.merge priv/gettext
```

When using Gettext backend:
- Translations are stored in `.po` files under `priv/gettext/`
- Use the "resources" domain for Ash resource translations
- Message IDs are formatted as `"resource_name.attribute_name"`
- Editing is managed through .po files, not the UI

## Mix Tasks

The package includes several Mix tasks for managing translations:

### Installation
```bash
# Install with database backend (default)
mix ash_phoenix_translations.install

# Install with gettext backend
mix ash_phoenix_translations.install --backend gettext

# Skip migration generation
mix ash_phoenix_translations.install --no-migration
```

## GraphQL Integration

Automatically expose translations through GraphQL:

```elixir
defmodule MyApp.Product do
  use Ash.Resource,
    extensions: [AshPhoenixTranslations, AshGraphql.Resource]
  
  graphql do
    type :product
    
    queries do
      get :get_product, :read
      list :list_products, :read
    end
  end
  
  translations do
    translatable_attribute :name, :string, locales: [:en, :es, :fr]
    graphql_translations true
  end
end
```

Query with locale:

```graphql
query {
  listProducts(locale: "es") {
    id
    name  # Automatically translated to Spanish
    nameTranslations {  # All translations
      locale
      value
    }
  }
}
```

## JSON:API Integration

Full JSON:API support with locale handling:

```elixir
defmodule MyApp.Product do
  use Ash.Resource,
    extensions: [AshPhoenixTranslations, AshJsonApi.Resource]
  
  json_api do
    type "product"
    
    routes do
      base "/products"
      get :read
      index :read
    end
  end
  
  translations do
    translatable_attribute :name, :string, locales: [:en, :es, :fr]
    json_api_translations true
  end
end
```

Add the locale plug to your router:

```elixir
pipeline :api do
  plug :accepts, ["json"]
  plug AshPhoenixTranslations.JsonApi.LocalePlug
end
```

Request with locale:

```bash
# Via query parameter
GET /api/products?locale=es

# Via Accept-Language header
GET /api/products
Accept-Language: es-ES,es;q=0.9
```

## Embedded Schema Support

Translate nested and embedded resources:

```elixir
defmodule MyApp.Address do
  use Ash.Resource,
    data_layer: :embedded,
    extensions: [AshPhoenixTranslations]
  
  translations do
    translatable_attribute :street, :string, locales: [:en, :es, :fr]
    translatable_attribute :city, :string, locales: [:en, :es, :fr]
  end
end

defmodule MyApp.User do
  use Ash.Resource,
    extensions: [AshPhoenixTranslations]
  
  attributes do
    attribute :address, MyApp.Address
  end
  
  translations do
    translatable_attribute :bio, :text, locales: [:en, :es, :fr]
    enable_embedded_translations true
  end
end
```

Translate embedded fields:

```elixir
user = MyApp.User |> Ash.get!(id)
translated = AshPhoenixTranslations.Embedded.translate_embedded(user, :es)
translated.address.street  # => Spanish street name
```

## Gettext Extraction

Extract translatable strings to POT files:

```bash
# Extract all translatable strings
mix ash_phoenix_translations.extract

# Extract for specific domain
mix ash_phoenix_translations.extract --domain MyApp.Shop

# Generate PO files for locales
mix ash_phoenix_translations.extract --locales en,es,fr

# Extract to custom directory
mix ash_phoenix_translations.extract --output priv/gettext
```

After extraction, use standard Gettext tools:

```bash
# Merge new strings
mix gettext.merge priv/gettext

# Compile translations
mix compile.gettext
```

## Import/Export

### Export Translations

```bash
# Export to CSV
mix ash_phoenix_translations.export products.csv --resource MyApp.Product

# Export only Spanish translations
mix ash_phoenix_translations.export spanish.json --resource MyApp.Product --locale es

# Export missing translations only
mix ash_phoenix_translations.export missing.csv --resource MyApp.Product --missing-only
```

### Import Translations

```bash
# Import from CSV
mix ash_phoenix_translations.import translations.csv --resource MyApp.Product

# Dry run to preview changes
mix ash_phoenix_translations.import translations.json --resource MyApp.Product --dry-run

# Replace existing translations
mix ash_phoenix_translations.import translations.csv --resource MyApp.Product --replace
```

### CSV Format

```csv
resource_id,field,locale,value
123e4567-e89b-12d3-a456-426614174000,name,en,Product Name
123e4567-e89b-12d3-a456-426614174000,name,es,Nombre del Producto
```

### JSON Format

```json
{
  "translations": [
    {
      "resource_id": "123e4567-e89b-12d3-a456-426614174000",
      "field": "name",
      "locale": "en",
      "value": "Product Name"
    }
  ]
}
```

## Validation

Validate translation completeness and quality:

```bash
# Validate all translations
mix ash_phoenix_translations.validate --resource MyApp.Product

# Validate specific locale
mix ash_phoenix_translations.validate --resource MyApp.Product --locale es

# Strict mode (exits with code 1 if issues found)
mix ash_phoenix_translations.validate --resource MyApp.Product --strict

# Output to JSON
mix ash_phoenix_translations.validate --resource MyApp.Product --format json --output report.json
```

## Caching

Built-in ETS-based caching with automatic invalidation:

```elixir
# Configure cache TTL per resource
translations do
  cache_ttl 7200  # 2 hours
end

# Manual cache operations
AshPhoenixTranslations.Cache.warm(Product, [:name, :description], [:en, :es])
AshPhoenixTranslations.Cache.invalidate_resource(Product, product_id)
AshPhoenixTranslations.Cache.invalidate_locale(:es)
AshPhoenixTranslations.Cache.stats()
# => %{size: 1234, hits: 5678, misses: 234, hit_rate: 96.0}
```

## Policy Integration

Leverage Ash's policy engine for translation access control:

```elixir
policies do
  # Anyone can view translations
  policy action_type(:read) do
    authorize_if always()
  end
  
  # Only translators can edit their assigned locale
  policy action_type(:update) do
    authorize_if expr(^actor(:role) == :translator and 
                     locale in ^actor(:assigned_locales))
  end
  
  # Admins can edit all translations
  policy action_type(:update) do
    authorize_if expr(^actor(:role) == :admin)
  end
end
```

## Advanced Features

### Translation Completeness

```elixir
# Check completeness
completeness = AshPhoenixTranslations.translation_completeness(product)
# => 83.3 (percentage)

# Get missing translations
missing = AshPhoenixTranslations.missing_translations(product)
# => [{:description, :fr}, {:tagline, :es}]
```

### Bulk Operations

```elixir
# Translate multiple resources
products = Product.list_products!()
translated = AshPhoenixTranslations.translate_all(products, :es)

# Warm cache for all products
AshPhoenixTranslations.Cache.warm(Product, [:name, :description], [:en, :es, :fr])
```

### Custom Locale Resolution

```elixir
plug AshPhoenixTranslations.Plugs.SetLocale,
  strategies: [:custom],
  custom: fn conn ->
    # Your custom logic
    get_locale_from_user(conn) || "en"
  end
```

### Audit Trail

Enable translation change tracking:

```elixir
translations do
  audit_changes true
  audit_actor_field :translator_id
end
```

## Configuration

```elixir
# config/config.exs
config :ash_phoenix_translations,
  default_backend: :database,
  default_locales: [:en, :es, :fr, :de],
  default_locale: :en,
  cache_ttl: 3600

# Configure cache (optional)
config :ash_phoenix_translations, AshPhoenixTranslations.Cache,
  ttl: 3600,
  max_size: 10000

# Configure PubSub for LiveView (optional)
config :ash_phoenix_translations,
  pubsub_server: MyApp.PubSub
```

## Testing

### Basic Testing Setup

```elixir
# In your test_helper.exs or case template
defmodule MyApp.DataCase do
  use ExUnit.CaseTemplate
  
  using do
    quote do
      alias MyApp.Repo
      import MyApp.DataCase
      import MyApp.Factory
    end
  end
  
  setup tags do
    # Clear translation cache before each test
    AshPhoenixTranslations.Cache.clear()
    
    # Set up database
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MyApp.Repo)
    
    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(MyApp.Repo, {:shared, self()})
    end
    
    :ok
  end
end
```

### Testing Translations

```elixir
defmodule MyApp.ProductTest do
  use MyApp.DataCase
  
  alias MyApp.Catalog.Product
  
  describe "creating products with translations" do
    test "creates product with multiple translations" do
      {:ok, product} = 
        Product.create(%{
          sku: "TEST-001",
          price: Decimal.new("99.99"),
          name_translations: %{
            en: "Test Product",
            es: "Producto de Prueba",
            fr: "Produit de Test"
          },
          description_translations: %{
            en: "A great test product",
            es: "Un gran producto de prueba",
            fr: "Un excellent produit de test"
          }
        })
      
      assert product.name_translations.en == "Test Product"
      assert product.name_translations.es == "Producto de Prueba"
      assert product.name_translations.fr == "Produit de Test"
    end
    
    test "handles missing translations gracefully" do
      {:ok, product} = 
        Product.create(%{
          sku: "TEST-002",
          price: Decimal.new("49.99"),
          name_translations: %{en: "Partial Product"}
        })
      
      # Get translated version
      spanish = AshPhoenixTranslations.translate(product, :es)
      
      # Should gracefully handle missing Spanish translation
      assert spanish.name == nil
    end
  end
  
  describe "translation completeness" do
    test "calculates completeness correctly" do
      product = insert(:product, 
        name_translations: %{en: "Test", es: "Prueba"},
        description_translations: %{en: "Description"}
      )
      
      # 3 out of 4 possible translations = 75%
      completeness = AshPhoenixTranslations.Helpers.translation_completeness(
        product, 
        locales: [:en, :es]
      )
      
      assert completeness == 75.0
    end
  end
  
  describe "translation validation" do
    test "validates required translations" do
      # This should fail because English is required
      assert {:error, changeset} = 
        Product.create(%{
          sku: "INVALID-001",
          price: Decimal.new("99.99"),
          name_translations: %{es: "Producto"}  # Missing required :en
        })
      
      assert changeset.errors[:name_translations]
    end
  end
end
```

### Testing Phoenix Integration

```elixir
defmodule MyAppWeb.ProductControllerTest do
  use MyAppWeb.ConnCase
  
  import MyApp.Factory
  
  describe "GET /products" do
    test "renders products in current locale", %{conn: conn} do
      product = insert(:product_with_translations)
      
      # Test English (default)
      conn = get(conn, ~p"/products")
      assert html_response(conn, 200) =~ "Test Product"
      
      # Test Spanish
      conn = 
        conn
        |> get(~p"/products?locale=es")
      
      assert html_response(conn, 200) =~ "Producto de Prueba"
    end
    
    test "falls back to default locale for missing translations", %{conn: conn} do
      product = insert(:product, 
        name_translations: %{en: "English Only"}
      )
      
      # Request Spanish but should fall back to English
      conn = get(conn, ~p"/products?locale=es")
      response = html_response(conn, 200)
      
      assert response =~ "English Only"
    end
  end
end
```

### Testing LiveView Integration

```elixir
defmodule MyAppWeb.ProductLiveTest do
  use MyAppWeb.ConnCase
  
  import Phoenix.LiveViewTest
  import MyApp.Factory
  
  describe "locale switching" do
    test "changes locale dynamically", %{conn: conn} do
      product = insert(:product_with_translations)
      
      {:ok, view, html} = live(conn, ~p"/live-products")
      
      # Should show English by default
      assert html =~ "Test Product"
      
      # Switch to Spanish
      html = 
        view
        |> element("select[name=locale]")
        |> render_change(%{locale: "es"})
      
      assert html =~ "Producto de Prueba"
    end
    
    test "updates translation form in real-time", %{conn: conn} do
      product = insert(:product)
      
      {:ok, view, _html} = live(conn, ~p"/live-products/#{product.id}/edit")
      
      # Update Spanish name
      view
      |> form("#product-form", product: %{
        name_translations: %{es: "Nuevo Nombre"}
      })
      |> render_change()
      
      # Check that progress indicator updates
      assert render(view) =~ "50%" # Assuming 1 out of 2 locales completed
    end
  end
end
```

## Admin Interface

A separate admin UI package is available for managing translations through a web interface:

```elixir
{:ash_phoenix_translations_admin, "~> 1.0.0"}
```

See [ash_phoenix_translations_admin](https://github.com/yourusername/ash_phoenix_translations_admin) for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Ash Framework](https://ash-hq.org/) team for the excellent framework
- Phoenix Framework community
- Contributors and users of this extension

## Support

- [Documentation](https://hexdocs.pm/ash_phoenix_translations)
- [GitHub Issues](https://github.com/raul-gracia/ash_phoenix_translations/issues)
- [Ash Discord](https://discord.gg/ash-hq)