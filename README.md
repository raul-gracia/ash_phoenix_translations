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
- 💾 **Multiple Storage Backends** - Database (JSONB), Gettext, Redis
- ⚡ **Performance Optimized** - Built-in caching with TTL and invalidation
- 🔄 **LiveView Integration** - Real-time locale switching and updates
- 📦 **Import/Export** - CSV, JSON, and XLIFF format support
- ✅ **Validation** - Built-in translation completeness and quality checks
- 🎨 **Phoenix Helpers** - Template helpers for easy translation rendering

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
    
    backend :database  # :database | :gettext | :redis
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
end
```

### Gettext Backend

Integrates with Phoenix's built-in Gettext:

```elixir
translations do
  backend :gettext
  gettext_domain "products"
end
```

### Redis Backend

For high-performance key-value storage:

```elixir
translations do
  backend :redis
  redis_ttl 86400  # 24 hours
end

# Configure Redis connection
config :ash_phoenix_translations, :redis,
  host: "localhost",
  port: 6379,
  database: 0
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
  cache_ttl: 3600,
  cache_backend: :ets,
  cache_max_size: 10000
```

## Testing

```elixir
# In your tests
setup do
  AshPhoenixTranslations.Cache.clear()
  :ok
end

test "creates product with translations" do
  {:ok, product} = 
    Product
    |> Ash.Changeset.for_create(:create, %{
      name_translations: %{en: "Test", es: "Prueba"}
    })
    |> Ash.create()
  
  assert product.name_translations.en == "Test"
  assert product.name_translations.es == "Prueba"
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