# AshPhoenixTranslations

[![CI](https://github.com/raul-gracia/ash_phoenix_translations/actions/workflows/ci.yml/badge.svg)](https://github.com/raul-gracia/ash_phoenix_translations/actions/workflows/ci.yml)
[![Security Audit](https://github.com/raul-gracia/ash_phoenix_translations/actions/workflows/security.yml/badge.svg)](https://github.com/raul-gracia/ash_phoenix_translations/actions/workflows/security.yml)
[![Code Quality](https://img.shields.io/badge/credo-passing-brightgreen.svg)](https://github.com/raul-gracia/ash_phoenix_translations/actions/workflows/ci.yml)
[![Security Analysis](https://img.shields.io/badge/sobelow-secure-brightgreen.svg)](https://github.com/raul-gracia/ash_phoenix_translations/actions/workflows/security.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/ash_phoenix_translations.svg)](https://hex.pm/packages/ash_phoenix_translations)
[![Hex Docs](https://img.shields.io/badge/hex-docs-purple.svg)](https://hexdocs.pm/ash_phoenix_translations)
[![License](https://img.shields.io/hexpm/l/ash_phoenix_translations.svg)](https://github.com/raul-gracia/ash_phoenix_translations/blob/main/LICENSE)

Policy-aware translation extension for [Ash Framework](https://ash-hq.org/) with multi-backend support, optimized for Phoenix applications.

> **🔒 Security-First Design**: Built with comprehensive security measures including XSS protection, input validation, and automated vulnerability scanning. See our [Security Policy](SECURITY.md) for details.

## Features

- 🌍 **Multi-locale Support** - Manage translations for unlimited locales per field
- 🔐 **Policy-aware** - Leverage Ash policies for translation access control
- 💾 **Multiple Storage Backends** - Database (JSONB ✅), Gettext (✅), Redis (✅)
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

**Optional Dependencies:**

For Redis backend support, you must add Redix to your dependencies:

```elixir
def deps do
  [
    {:ash_phoenix_translations, "~> 1.0.0"},
    {:redix, "~> 1.5"}  # Required only for Redis backend
  ]
end
```

> **Note**: The Redis backend is fully implemented but requires the optional `redix` dependency. Database and Gettext backends work out of the box without additional dependencies.

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

### Redis Backend

Uses Redis for distributed translation storage with high performance:

```elixir
translations do
  backend :redis

  translatable_attribute :name, :string do
    locales [:en, :es, :fr]
  end
end
```

**Redis Setup:**

> **Important**: The Redis backend requires the `redix` package. Add `{:redix, "~> 1.5"}` to your `mix.exs` dependencies before proceeding.

```bash
# 1. Add Redix to mix.exs dependencies (see Installation section)
# 2. Install dependencies
mix deps.get

# 3. Install with Redis backend
mix ash_phoenix_translations.install --backend redis
```

**Configuration:**
```elixir
# config/config.exs
config :ash_phoenix_translations,
  redis_url: "redis://localhost:6379",
  redis_pool_size: 10
```

**Key Features:**
- **Distributed Storage**: Translations stored in Redis for multi-server deployments
- **High Performance**: Redis's in-memory storage provides fast translation lookups
- **Local Caching**: Automatic local cache to reduce Redis round trips
- **TTL Support**: Optional expiration for translation cache keys
- **Pattern-based Keys**: `translations:{resource}:{id}:{field}:{locale}`

**Storage Pattern:**
```
Key: translations:Product:123:name:en
Value: "Laptop"

Key: translations:Product:123:name:es
Value: "Portátil"
```

**Local Cache Attributes:**
- Each translatable field gets a `{field}_cache` attribute for local caching
- Cache reduces Redis calls after initial load
- Automatically managed by calculation module

**Use Cases:**
- Multi-server deployments requiring shared translation state
- High-traffic applications needing fast translation lookups
- Applications with frequent translation updates
- Microservices architectures with centralized translation service

## Mix Tasks

The package includes several Mix tasks for managing translations:

### Installation
```bash
# Install with database backend (default)
mix ash_phoenix_translations.install

# Install with gettext backend
mix ash_phoenix_translations.install --backend gettext

# Install with Redis backend
mix ash_phoenix_translations.install --backend redis

# Skip migration generation
mix ash_phoenix_translations.install --no-migration
```

### Redis Backend Tasks

The Redis backend includes specialized Mix tasks for managing translations:

#### Export from Redis
```bash
# Export all translations to CSV
mix ash_phoenix_translations.export.redis output.csv --resource MyApp.Product

# Export to JSON format
mix ash_phoenix_translations.export.redis translations.json --format json --resource MyApp.Product

# Export specific locale
mix ash_phoenix_translations.export.redis spanish.csv --resource MyApp.Product --locale es

# Export specific fields
mix ash_phoenix_translations.export.redis names.csv --resource MyApp.Product --field name,description

# Export all resources
mix ash_phoenix_translations.export.redis all.json --all-resources --format json
```

#### Import to Redis
```bash
# Import from CSV
mix ash_phoenix_translations.import.redis translations.csv

# Import from JSON
mix ash_phoenix_translations.import.redis data.json --format json

# Dry run (preview changes)
mix ash_phoenix_translations.import.redis data.csv --dry-run

# Import with TTL
mix ash_phoenix_translations.import.redis data.csv --ttl 3600

# Overwrite existing translations
mix ash_phoenix_translations.import.redis data.csv --overwrite
```

#### Sync Between Backends
```bash
# Sync from database to Redis
mix ash_phoenix_translations.sync.redis --from database --to redis --resource MyApp.Product

# Sync from Redis to database
mix ash_phoenix_translations.sync.redis --from redis --to database --resource MyApp.Product

# Bidirectional sync (keep both in sync)
mix ash_phoenix_translations.sync.redis --bidirectional --resource MyApp.Product

# Dry run
mix ash_phoenix_translations.sync.redis --from database --to redis --resource MyApp.Product --dry-run
```

#### Clear Redis Translations
```bash
# Clear all translations for a resource
mix ash_phoenix_translations.clear.redis --resource MyApp.Product --confirm

# Clear specific field
mix ash_phoenix_translations.clear.redis --resource MyApp.Product --field name --confirm

# Clear specific locale
mix ash_phoenix_translations.clear.redis --resource MyApp.Product --locale es --confirm

# Preview deletions (dry run)
mix ash_phoenix_translations.clear.redis --resource MyApp.Product --dry-run

# Clear all translations (use with caution!)
mix ash_phoenix_translations.clear.redis --all --confirm
```

#### Redis Information
```bash
# Show Redis statistics
mix ash_phoenix_translations.info.redis

# Show resource-specific info
mix ash_phoenix_translations.info.redis --resource MyApp.Product

# Detailed breakdown
mix ash_phoenix_translations.info.redis --resource MyApp.Product --detailed
```

#### Validate Redis Translations
```bash
# Validate all translations
mix ash_phoenix_translations.validate.redis --resource MyApp.Product

# Validate specific locale
mix ash_phoenix_translations.validate.redis --resource MyApp.Product --locale es

# Strict mode (fail on warnings)
mix ash_phoenix_translations.validate.redis --resource MyApp.Product --strict

# Check for orphaned keys
mix ash_phoenix_translations.validate.redis --resource MyApp.Product --check-orphaned
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

### Basic Configuration

The simplest configuration using default settings:

```elixir
# config/config.exs
config :ash_phoenix_translations,
  default_backend: :database,
  default_locales: [:en, :es, :fr],
  default_locale: :en
```

### Complete Configuration Reference

```elixir
# config/config.exs
config :ash_phoenix_translations,
  # Backend Settings
  default_backend: :database,        # :database | :gettext | :redis
  default_locales: [:en, :es, :fr, :de, :it, :pt, :ja, :zh],
  default_locale: :en,

  # Caching Configuration
  cache_ttl: 3600,                   # Cache TTL in seconds (1 hour)
  cache_enabled: true,               # Enable/disable caching globally

  # Security Configuration
  supported_locales: [:en, :es, :fr, :de, :it, :pt, :ja, :zh, :ko, :ar, :ru],
  cache_secret: :crypto.strong_rand_bytes(32),  # HMAC signing secret

  # LiveView PubSub (optional)
  pubsub_server: MyApp.PubSub,

  # Audit Configuration (optional)
  audit_enabled: true,
  audit_retention_days: 90

# Redis Backend Configuration (if using Redis)
config :ash_phoenix_translations,
  redis_url: System.get_env("REDIS_URL") || "redis://localhost:6379",
  redis_pool_size: 10,
  redis_connection_opts: [
    socket_opts: [:inet6],
    ssl: true,
    timeout: 5000
  ]

# Cache Settings (fine-tuning)
config :ash_phoenix_translations, AshPhoenixTranslations.Cache,
  ttl: 3600,                         # Default TTL for cache entries
  max_size: 10_000,                  # Maximum number of cache entries
  cleanup_interval: 300,             # Cleanup expired entries every 5 minutes
  enable_stats: true                 # Track cache statistics
```

### Configuration by Environment

#### Development Environment

```elixir
# config/dev.exs
import Config

config :ash_phoenix_translations,
  default_backend: :database,
  default_locales: [:en, :es],      # Fewer locales for faster dev
  cache_ttl: 60,                     # Short cache for live reloading
  cache_enabled: false               # Disable cache to see changes immediately
```

#### Test Environment

```elixir
# config/test.exs
import Config

config :ash_phoenix_translations,
  default_backend: :database,
  default_locales: [:en, :es, :fr],
  cache_enabled: false,              # No caching in tests for predictability
  audit_enabled: false               # Disable audit for faster tests
```

#### Production Environment

```elixir
# config/runtime.exs
import Config

if config_env() == :prod do
  config :ash_phoenix_translations,
    default_backend: :redis,         # Redis for distributed deployments
    redis_url: System.fetch_env!("REDIS_URL"),
    redis_pool_size: String.to_integer(System.get_env("REDIS_POOL_SIZE", "20")),
    cache_ttl: 7200,                 # Longer cache in production (2 hours)
    cache_enabled: true,
    audit_enabled: true,
    cache_secret: System.fetch_env!("CACHE_SECRET")
end
```

### Configuration Scenarios

#### Scenario 1: Small Application (Single Server)

**Use Case**: Small Phoenix app running on a single server with moderate traffic.

```elixir
# config/config.exs
config :ash_phoenix_translations,
  default_backend: :database,        # Simple database storage
  default_locales: [:en, :es, :fr],
  cache_ttl: 3600,                   # 1-hour cache is sufficient
  audit_enabled: false               # Skip audit for simplicity

# In your resource
translations do
  translatable_attribute :name, :string, locales: [:en, :es, :fr]
  backend :database
  cache_ttl 3600
end
```

#### Scenario 2: Multi-Server Deployment

**Use Case**: Phoenix app deployed across multiple servers, needs shared translation state.

```elixir
# config/runtime.exs
config :ash_phoenix_translations,
  default_backend: :redis,           # Shared state across servers
  redis_url: System.fetch_env!("REDIS_URL"),
  redis_pool_size: 20,
  cache_ttl: 7200,                   # 2-hour cache
  pubsub_server: MyApp.PubSub        # Coordinate LiveView updates

# In your resource
translations do
  translatable_attribute :name, :string, locales: [:en, :es, :fr, :de]
  backend :redis
  cache_ttl 7200
end
```

#### Scenario 3: Content Management System

**Use Case**: CMS with frequent translation updates, need audit trail.

```elixir
# config/config.exs
config :ash_phoenix_translations,
  default_backend: :database,
  cache_ttl: 300,                    # Short cache (5 min) for fresh content
  audit_enabled: true,
  audit_retention_days: 365          # Keep audit trail for 1 year

# In your resource
translations do
  translatable_attribute :title, :string, locales: [:en, :es, :fr, :de, :it]
  translatable_attribute :content, :text, locales: [:en, :es, :fr, :de, :it]

  backend :database
  cache_ttl 300
  audit_changes true
  audit_actor_field :editor_id      # Track who made changes
end
```

#### Scenario 4: Gettext Integration

**Use Case**: Existing Phoenix app using Gettext, want to integrate with Ash resources.

```elixir
# config/config.exs
config :ash_phoenix_translations,
  default_backend: :gettext,
  default_locales: [:en, :es, :fr]

# In your resource
translations do
  translatable_attribute :name, :string, locales: [:en, :es, :fr]
  translatable_attribute :description, :text, locales: [:en, :es, :fr]

  backend :gettext
  gettext_module MyAppWeb.Gettext   # Required for Gettext backend
  gettext_domain "resources"        # Optional, defaults to "resources"
end
```

#### Scenario 5: High-Performance E-commerce

**Use Case**: E-commerce platform with high traffic, need maximum performance.

```elixir
# config/runtime.exs
config :ash_phoenix_translations,
  default_backend: :redis,
  redis_url: System.fetch_env!("REDIS_URL"),
  redis_pool_size: 50,               # Large pool for high concurrency
  cache_ttl: 14400,                  # 4-hour cache for stable content
  cache_enabled: true

# Additional cache tuning
config :ash_phoenix_translations, AshPhoenixTranslations.Cache,
  ttl: 14400,
  max_size: 100_000,                 # Large cache for product catalog
  cleanup_interval: 600,
  enable_stats: true

# In your Product resource
translations do
  translatable_attribute :name, :string,
    locales: [:en, :es, :fr, :de, :it, :pt, :ja, :zh],
    required: [:en]

  translatable_attribute :description, :text,
    locales: [:en, :es, :fr, :de, :it, :pt, :ja, :zh]

  backend :redis
  cache_ttl 14400                    # Match global cache
end
```

### Backend-Specific Configuration

#### Database Backend Configuration

```elixir
# config/config.exs
config :ash_phoenix_translations,
  default_backend: :database

# Run migration after installation
# mix ash_phoenix_translations.install --backend database
# mix ecto.migrate

# In your resource
translations do
  translatable_attribute :name, :string, locales: [:en, :es, :fr]

  backend :database
  # Translations stored in {field}_translations JSONB columns
  cache_ttl 3600
  audit_changes true  # Optional: track translation changes
end
```

**Database Schema Example:**
```sql
CREATE TABLE products (
  id UUID PRIMARY KEY,
  sku VARCHAR(255),
  name_translations JSONB,           -- Stores: {"en": "Product", "es": "Producto"}
  description_translations JSONB,    -- Stores: {"en": "Description", "es": "Descripción"}
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

CREATE INDEX idx_products_name_translations ON products USING GIN (name_translations);
```

#### Gettext Backend Configuration

```elixir
# config/config.exs
config :ash_phoenix_translations,
  default_backend: :gettext

# Install Gettext directories
# mix ash_phoenix_translations.install --backend gettext

# In your resource
translations do
  translatable_attribute :name, :string, locales: [:en, :es, :fr]

  backend :gettext
  gettext_module MyAppWeb.Gettext   # REQUIRED for Gettext
  gettext_domain "resources"        # Optional, defaults to "resources"
end

# Extract strings to .pot files
# mix ash_phoenix_translations.extract --locales en,es,fr
# mix gettext.merge priv/gettext
```

**Gettext File Structure:**
```
priv/gettext/
├── default.pot
├── resources.pot              # Extracted resource translations
├── en/
│   └── LC_MESSAGES/
│       ├── default.po
│       └── resources.po       # Product.name, Product.description
├── es/
│   └── LC_MESSAGES/
│       ├── default.po
│       └── resources.po
└── fr/
    └── LC_MESSAGES/
        ├── default.po
        └── resources.po
```

#### Redis Backend Configuration

```elixir
# config/runtime.exs
config :ash_phoenix_translations,
  default_backend: :redis,
  redis_url: System.get_env("REDIS_URL", "redis://localhost:6379"),
  redis_pool_size: 10

# Ensure Redix dependency is added to mix.exs
# {:redix, "~> 1.5"}

# In your resource
translations do
  translatable_attribute :name, :string, locales: [:en, :es, :fr]

  backend :redis
  cache_ttl 7200  # Local cache reduces Redis calls
end

# Sync existing database translations to Redis
# mix ash_phoenix_translations.sync.redis --from database --to redis --resource MyApp.Product
```

**Redis Key Structure:**
```
translations:Product:123e4567:name:en → "Product Name"
translations:Product:123e4567:name:es → "Nombre del Producto"
translations:Product:123e4567:description:en → "Product Description"
```

### Security Configuration

```elixir
# config/config.exs
config :ash_phoenix_translations,
  # Locale Validation - Prevent atom exhaustion attacks
  supported_locales: [:en, :es, :fr, :de, :it, :pt, :ja, :zh, :ko, :ar, :ru],

  # Cache Security - HMAC signing for cached values
  cache_secret: System.get_env("CACHE_SECRET") || :crypto.strong_rand_bytes(32),

  # XSS Protection - All helpers escape HTML by default
  # Use t_raw/2 only with trusted content

  # Input Sanitization - Enabled by default
  sanitize_input: true,

  # Rate Limiting (optional, requires separate package)
  # rate_limit: [
  #   translation_updates: {10, :per_minute},
  #   import_operations: {5, :per_hour}
  # ]

# Production: Use environment variables for secrets
# config/runtime.exs
if config_env() == :prod do
  config :ash_phoenix_translations,
    cache_secret: System.fetch_env!("CACHE_SECRET"),  # 32+ bytes
    redis_url: System.fetch_env!("REDIS_URL")
end
```

### Performance Tuning Configuration

```elixir
# config/config.exs
config :ash_phoenix_translations,
  # Cache Configuration
  cache_ttl: 7200,                   # 2 hours
  cache_enabled: true,

# Advanced cache settings
config :ash_phoenix_translations, AshPhoenixTranslations.Cache,
  ttl: 7200,
  max_size: 50_000,                  # Adjust based on dataset size
  cleanup_interval: 300,             # Cleanup every 5 minutes
  enable_stats: true,                # Monitor cache performance
  eviction_policy: :lru              # Least Recently Used eviction

# Redis connection tuning
config :ash_phoenix_translations,
  redis_pool_size: 20,               # Match your load
  redis_connection_opts: [
    timeout: 5000,
    socket_opts: [:inet6],
    keepalive: true
  ]

# Database query optimization
config :my_app, MyApp.Repo,
  pool_size: 20,
  queue_target: 50,
  queue_interval: 1000

# In your resources - per-resource cache tuning
translations do
  translatable_attribute :name, :string, locales: [:en, :es, :fr]

  backend :database
  cache_ttl 14400  # 4 hours for stable content like product names
end

translations do
  translatable_attribute :price, :decimal, locales: [:en, :es, :fr]

  backend :database
  cache_ttl 300    # 5 minutes for dynamic content like prices
end
```

## Real-World Examples

This section provides complete, production-ready examples for common use cases.

### Example 1: E-commerce Product Catalog

**Scenario**: Multi-language e-commerce platform with products, categories, and reviews.

#### Step 1: Define the Product Resource

```elixir
# lib/my_shop/catalog/resources/product.ex
defmodule MyShop.Catalog.Product do
  use Ash.Resource,
    domain: MyShop.Catalog,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshPhoenixTranslations]

  postgres do
    table "products"
    repo MyShop.Repo
  end

  translations do
    # Product name in multiple languages
    translatable_attribute :name, :string do
      locales [:en, :es, :fr, :de, :it, :pt, :ja, :zh]
      required [:en]  # English is mandatory
    end

    # Product description with markdown support
    translatable_attribute :description, :text do
      locales [:en, :es, :fr, :de, :it, :pt, :ja, :zh]
      markdown true
    end

    # Short marketing tagline
    translatable_attribute :tagline, :string do
      locales [:en, :es, :fr, :de, :it, :pt, :ja, :zh]
    end

    # SEO-friendly slug
    translatable_attribute :slug, :string do
      locales [:en, :es, :fr, :de, :it, :pt, :ja, :zh]
    end

    backend :database
    cache_ttl 3600
    audit_changes true
  end

  attributes do
    uuid_primary_key :id
    attribute :sku, :string, allow_nil?: false
    attribute :price, :decimal, allow_nil?: false
    attribute :stock_quantity, :integer, default: 0
    attribute :active, :boolean, default: true
    timestamps()
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:sku, :price, :stock_quantity, :active]
      accept [:name_translations, :description_translations, :tagline_translations, :slug_translations]
    end

    update :update do
      accept [:sku, :price, :stock_quantity, :active]
      accept [:name_translations, :description_translations, :tagline_translations, :slug_translations]
    end

    # Custom action for bulk translation updates
    update :update_translations do
      accept [:name_translations, :description_translations, :tagline_translations]

      change fn changeset, _context ->
        # Automatically update slug when name changes
        if Ash.Changeset.changing_attribute?(changeset, :name_translations) do
          name_trans = Ash.Changeset.get_attribute(changeset, :name_translations)
          slug_trans = Enum.map(name_trans, fn {locale, name} ->
            {locale, Slug.slugify(name)}
          end) |> Enum.into(%{})

          Ash.Changeset.force_change_attribute(changeset, :slug_translations, slug_trans)
        else
          changeset
        end
      end
    end
  end

  relationships do
    belongs_to :category, MyShop.Catalog.Category
    has_many :reviews, MyShop.Catalog.Review
  end
end
```

#### Step 2: Phoenix Controller Integration

```elixir
# lib/my_shop_web/controllers/product_controller.ex
defmodule MyShopWeb.ProductController do
  use MyShopWeb, :controller

  alias MyShop.Catalog.Product

  def index(conn, _params) do
    # Get current locale from conn (set by SetLocale plug)
    locale = conn.assigns.locale

    # Load products and translate them
    products =
      Product
      |> Ash.read!()
      |> Enum.map(&AshPhoenixTranslations.translate(&1, locale))

    render(conn, "index.html", products: products, locale: locale)
  end

  def show(conn, %{"id" => id}) do
    locale = conn.assigns.locale

    product =
      Product
      |> Ash.get!(id)
      |> AshPhoenixTranslations.translate(locale)

    # Calculate translation completeness for admin display
    completeness = AshPhoenixTranslations.translation_completeness(product)

    render(conn, "show.html",
      product: product,
      locale: locale,
      completeness: completeness
    )
  end

  def edit(conn, %{"id" => id}) do
    product = Ash.get!(Product, id)
    changeset = Ash.Changeset.for_update(product, :update_translations)

    render(conn, "edit.html",
      product: product,
      changeset: changeset,
      locales: [:en, :es, :fr, :de]
    )
  end

  def update(conn, %{"id" => id, "product" => product_params}) do
    product = Ash.get!(Product, id)

    case Ash.update(product, :update_translations, product_params) do
      {:ok, updated_product} ->
        conn
        |> put_flash(:info, "Product translations updated successfully")
        |> redirect(to: ~p"/products/#{updated_product.id}")

      {:error, changeset} ->
        render(conn, "edit.html",
          product: product,
          changeset: changeset,
          locales: [:en, :es, :fr, :de]
        )
    end
  end
end
```

#### Step 3: Phoenix Templates with Translation Helpers

```elixir
# lib/my_shop_web/controllers/product_html/index.html.heex
<div class="products-grid">
  <div class="language-switcher">
    <%= language_switcher(@conn, Product) %>
  </div>

  <div class="products">
    <%= for product <- @products do %>
      <article class="product-card">
        <h2><%= t(product, :name) %></h2>
        <p class="tagline"><%= t(product, :tagline, fallback: "New Product") %></p>
        <div class="price">$<%= product.price %></div>
        <%= link "View Details", to: ~p"/products/#{product.id}" %>
      </article>
    <% end %>
  </div>
</div>

# lib/my_shop_web/controllers/product_html/show.html.heex
<div class="product-detail">
  <h1><%= t(@product, :name) %></h1>

  <%= if @conn.assigns.current_user && @conn.assigns.current_user.role == :admin do %>
    <div class="admin-info">
      <span>Translation Completeness: <%= @completeness %>%</span>
      <%= translation_status(@product, :description) %>
    </div>
  <% end %>

  <div class="description">
    <%= t_raw(@product, :description) |> markdown_to_html() %>
  </div>

  <div class="meta">
    <span>SKU: <%= @product.sku %></span>
    <span>Stock: <%= @product.stock_quantity %></span>
  </div>
</div>

# lib/my_shop_web/controllers/product_html/edit.html.heex
<div class="translation-editor">
  <.form :let={f} for={@changeset} action={~p"/products/#{@product.id}"}>

    <!-- Translation tabs for each locale -->
    <div class="locale-tabs">
      <%= for locale <- @locales do %>
        <button type="button" data-locale={locale} class="tab">
          <%= locale |> to_string |> String.upcase %>
          <%= translation_status_badge(@product, :name, locale) %>
        </button>
      <% end %>
    </div>

    <!-- Name translations -->
    <div class="form-group">
      <label>Product Name</label>
      <%= for locale <- @locales do %>
        <div class="locale-input" data-locale={locale}>
          <%= text_input f, :"name_translations_#{locale}",
              value: get_in(@product.name_translations, [locale]),
              placeholder: "Product name in #{locale}" %>
        </div>
      <% end %>
    </div>

    <!-- Description translations -->
    <div class="form-group">
      <label>Description</label>
      <%= for locale <- @locales do %>
        <div class="locale-input" data-locale={locale}>
          <%= textarea f, :"description_translations_#{locale}",
              value: get_in(@product.description_translations, [locale]),
              placeholder: "Description in #{locale}",
              rows: 10 %>
        </div>
      <% end %>
    </div>

    <!-- Translation progress indicator -->
    <div class="progress">
      <.translation_progress resource={@product} />
    </div>

    <div class="actions">
      <%= submit "Save Translations", class: "btn-primary" %>
      <%= link "Cancel", to: ~p"/products/#{@product.id}", class: "btn-secondary" %>
    </div>
  </.form>
</div>
```

#### Step 4: LiveView Real-time Translation Editor

```elixir
# lib/my_shop_web/live/product_live/translation_editor.ex
defmodule MyShopWeb.ProductLive.TranslationEditor do
  use MyShopWeb, :live_view
  use AshPhoenixTranslations.LiveView

  alias MyShop.Catalog.Product

  def mount(%{"id" => id}, _session, socket) do
    product = Ash.get!(Product, id)

    socket =
      socket
      |> assign(:product, product)
      |> assign(:locales, [:en, :es, :fr, :de, :it])
      |> assign(:current_locale, :en)
      |> assign(:unsaved_changes, %{})
      |> assign_translation_progress(product)

    {:ok, socket}
  end

  def handle_event("change_locale", %{"locale" => locale}, socket) do
    {:noreply, assign(socket, :current_locale, String.to_existing_atom(locale))}
  end

  def handle_event("update_translation", %{"field" => field, "locale" => locale, "value" => value}, socket) do
    field_atom = String.to_existing_atom(field)
    locale_atom = String.to_existing_atom(locale)

    # Track unsaved changes
    unsaved =
      socket.assigns.unsaved_changes
      |> Map.put({field_atom, locale_atom}, value)

    # Update progress calculation
    socket =
      socket
      |> assign(:unsaved_changes, unsaved)
      |> assign_translation_progress(socket.assigns.product, unsaved)

    {:noreply, socket}
  end

  def handle_event("save_all", _params, socket) do
    product = socket.assigns.product
    changes = build_translation_changes(socket.assigns.unsaved_changes)

    case Ash.update(product, :update_translations, changes) do
      {:ok, updated_product} ->
        socket =
          socket
          |> assign(:product, updated_product)
          |> assign(:unsaved_changes, %{})
          |> put_flash(:info, "Translations saved successfully")

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save: #{inspect(changeset.errors)}")}
    end
  end

  defp assign_translation_progress(socket, product, changes \\ %{}) do
    # Calculate progress with unsaved changes
    completeness = calculate_progress_with_changes(product, changes)
    assign(socket, :translation_progress, completeness)
  end

  defp build_translation_changes(unsaved) do
    Enum.reduce(unsaved, %{}, fn {{field, locale}, value}, acc ->
      field_key = :"#{field}_translations"
      translations = Map.get(acc, field_key, %{})
      Map.put(acc, field_key, Map.put(translations, locale, value))
    end)
  end
end
```

### Example 2: Content Management System

**Scenario**: Blog/CMS with articles, pages, and custom content blocks.

#### Resource Definition

```elixir
# lib/my_cms/content/resources/article.ex
defmodule MyCMS.Content.Article do
  use Ash.Resource,
    domain: MyCMS.Content,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshPhoenixTranslations]

  postgres do
    table "articles"
    repo MyCMS.Repo
  end

  translations do
    translatable_attribute :title, :string do
      locales [:en, :es, :fr, :de]
      required [:en]
    end

    translatable_attribute :content, :text do
      locales [:en, :es, :fr, :de]
      markdown true
      required [:en]
    end

    translatable_attribute :excerpt, :text do
      locales [:en, :es, :fr, :de]
    end

    translatable_attribute :meta_description, :string do
      locales [:en, :es, :fr, :de]
    end

    backend :database
    cache_ttl 300  # 5 minutes - content changes frequently
    audit_changes true
    audit_actor_field :author_id
  end

  attributes do
    uuid_primary_key :id
    attribute :slug, :string, allow_nil?: false
    attribute :published, :boolean, default: false
    attribute :published_at, :utc_datetime
    attribute :featured, :boolean, default: false
    timestamps()
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:slug, :published, :featured]
      accept [:title_translations, :content_translations, :excerpt_translations, :meta_description_translations]

      change fn changeset, _context ->
        # Auto-generate excerpt from content if not provided
        if !Ash.Changeset.changing_attribute?(changeset, :excerpt_translations) do
          content_trans = Ash.Changeset.get_attribute(changeset, :content_translations) || %{}
          excerpt_trans = Enum.map(content_trans, fn {locale, content} ->
            excerpt = content |> String.slice(0, 200) |> Kernel.<>("...")
            {locale, excerpt}
          end) |> Enum.into(%{})

          Ash.Changeset.force_change_attribute(changeset, :excerpt_translations, excerpt_trans)
        else
          changeset
        end
      end
    end

    update :update do
      accept [:slug, :published, :featured, :published_at]
      accept [:title_translations, :content_translations, :excerpt_translations, :meta_description_translations]
    end

    update :publish do
      change set_attribute(:published, true)
      change set_attribute(:published_at, &DateTime.utc_now/0)
    end

    update :unpublish do
      change set_attribute(:published, false)
    end
  end

  relationships do
    belongs_to :author, MyCMS.Accounts.User
    many_to_many :tags, MyCMS.Content.Tag do
      through MyCMS.Content.ArticleTag
      source_attribute_on_join_resource :article_id
      destination_attribute_on_join_resource :tag_id
    end
  end

  policies do
    # Public can read published articles
    policy action_type(:read) do
      authorize_if expr(published == true)
    end

    # Authors can manage their own articles
    policy action_type([:create, :update]) do
      authorize_if expr(author_id == ^actor(:id))
    end

    # Editors can manage all articles
    policy action_type(:update) do
      authorize_if actor_attribute_equals(:role, :editor)
    end
  end
end
```

#### Translation Workflow for Editors

```elixir
# lib/my_cms_web/live/article_live/edit.ex
defmodule MyCMSWeb.ArticleLive.Edit do
  use MyCMSWeb, :live_view
  use AshPhoenixTranslations.LiveView

  alias MyCMS.Content.Article

  def mount(%{"id" => id}, _session, socket) do
    article = Ash.get!(Article, id)

    socket =
      socket
      |> assign(:article, article)
      |> assign(:locales, [:en, :es, :fr, :de])
      |> assign(:current_locale, :en)
      |> assign(:preview_mode, false)
      |> assign_translation_status()

    {:ok, socket}
  end

  def handle_event("switch_locale", %{"locale" => locale}, socket) do
    {:noreply, assign(socket, :current_locale, String.to_existing_atom(locale))}
  end

  def handle_event("toggle_preview", _params, socket) do
    {:noreply, update(socket, :preview_mode, &(!&1))}
  end

  def handle_event("save_translation", params, socket) do
    article = socket.assigns.article
    locale = socket.assigns.current_locale

    # Build update params for current locale only
    updates = %{
      "title_translations" => Map.put(article.title_translations || %{}, locale, params["title"]),
      "content_translations" => Map.put(article.content_translations || %{}, locale, params["content"]),
      "excerpt_translations" => Map.put(article.excerpt_translations || %{}, locale, params["excerpt"])
    }

    case Ash.update(article, :update, updates) do
      {:ok, updated_article} ->
        socket =
          socket
          |> assign(:article, updated_article)
          |> assign_translation_status()
          |> put_flash(:info, "Translation saved for #{locale}")

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save: #{format_errors(changeset)}")}
    end
  end

  defp assign_translation_status(socket) do
    article = socket.assigns.article

    status =
      Enum.map(socket.assigns.locales, fn locale ->
        completeness = AshPhoenixTranslations.Helpers.translation_completeness(article, locales: [locale])
        {locale, completeness}
      end)
      |> Enum.into(%{})

    assign(socket, :translation_status, status)
  end
end
```

### Example 3: Multi-tenant SaaS Application

**Scenario**: SaaS platform where each tenant can manage their own translations.

```elixir
# lib/my_saas/core/resources/company.ex
defmodule MySaaS.Core.Company do
  use Ash.Resource,
    domain: MySaaS.Core,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshPhoenixTranslations]

  postgres do
    table "companies"
    repo MySaaS.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :tenant_id
  end

  translations do
    translatable_attribute :name, :string do
      locales [:en, :es, :fr, :de, :pt]
      required [:en]
    end

    translatable_attribute :description, :text do
      locales [:en, :es, :fr, :de, :pt]
    end

    backend :redis  # Use Redis for multi-tenant scalability
    cache_ttl 7200
  end

  attributes do
    uuid_primary_key :id
    attribute :tenant_id, :uuid
    attribute :domain, :string
    timestamps()
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:tenant_id, :domain, :name_translations, :description_translations]
    end

    update :update do
      accept [:domain, :name_translations, :description_translations]
    end
  end
end

# Access with tenant context
defmodule MySaaSWeb.CompanyController do
  use MySaaSWeb, :controller

  def show(conn, %{"id" => id}) do
    # Get tenant from current user
    tenant_id = conn.assigns.current_user.tenant_id
    locale = conn.assigns.locale

    company =
      MySaaS.Core.Company
      |> Ash.Query.filter(tenant_id == ^tenant_id)
      |> Ash.get!(id)
      |> AshPhoenixTranslations.translate(locale)

    render(conn, "show.html", company: company)
  end
end
```

### Example 4: Import/Export Workflow

**Scenario**: Regular translation import/export for external translation services.

```bash
# Export current translations for translation service
mix ash_phoenix_translations.export translations_export.csv \
  --resource MyApp.Product \
  --missing-only

# External service fills in translations
# translations_import.csv now has completed translations

# Preview changes before importing
mix ash_phoenix_translations.import translations_import.csv \
  --resource MyApp.Product \
  --dry-run

# Import with validation
mix ash_phoenix_translations.import translations_import.csv \
  --resource MyApp.Product

# Validate translation quality
mix ash_phoenix_translations.validate \
  --resource MyApp.Product \
  --strict \
  --output validation_report.json \
  --format json
```

### Example 5: GraphQL API with Translations

```elixir
# lib/my_app/catalog/resources/product.ex
defmodule MyApp.Catalog.Product do
  use Ash.Resource,
    domain: MyApp.Catalog,
    extensions: [AshPhoenixTranslations, AshGraphql.Resource]

  graphql do
    type :product

    queries do
      get :product, :read
      list :products, :read
    end

    mutations do
      create :create_product, :create
      update :update_product, :update
    end
  end

  translations do
    translatable_attribute :name, :string, locales: [:en, :es, :fr]
    translatable_attribute :description, :text, locales: [:en, :es, :fr]

    backend :database
    graphql_translations true  # Expose translations in GraphQL
  end
end

# GraphQL queries with locale
"""
query GetProduct($id: ID!, $locale: String!) {
  product(id: $id, locale: $locale) {
    id
    name        # Automatically translated to requested locale
    description

    # Access all translations
    nameTranslations {
      locale
      value
    }
  }
}

query ListProducts($locale: String!) {
  products(locale: $locale) {
    id
    name
    description
  }
}

mutation UpdateProductTranslations($id: ID!, $translations: ProductTranslationsInput!) {
  updateProduct(id: $id, input: {
    nameTranslations: $translations.name
    descriptionTranslations: $translations.description
  }) {
    id
    name
    nameTranslations {
      locale
      value
    }
  }
}
"""
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

## Security

AshPhoenixTranslations is built with security as a primary concern. We implement comprehensive security measures including:

- **XSS Prevention**: All translation output is HTML-escaped by default
- **Atom Safety**: Uses `String.to_existing_atom/1` to prevent atom exhaustion attacks
- **Input Validation**: Comprehensive validation of all translation content
- **Automated Security Scanning**: Sobelow security analysis in CI/CD pipeline
- **Dependency Auditing**: Regular vulnerability scans of all dependencies

### Security Features

- 🛡️ **XSS Protection** - HTML escaping for all translation output
- 🔒 **Input Sanitization** - Validation and sanitization of translation data
- ⚡ **Atom Safety** - Secure locale parameter handling preventing DoS attacks
- 🔍 **Security Scanning** - Automated Sobelow and dependency vulnerability scans
- 📋 **Security Policies** - Comprehensive security documentation and guidelines

For detailed security information, see our [Security Policy](SECURITY.md).

### Reporting Security Issues

If you discover a security vulnerability, please report it responsibly by emailing security@yourproject.com. Do not open public issues for security vulnerabilities.

## Quality Assurance

We maintain high code quality standards through:

### Code Quality Tools

- **Credo**: Strict code analysis and style enforcement
- **Dialyzer**: Static type analysis for bug detection
- **ExCoveralls**: Test coverage monitoring (>90% required)
- **Sobelow**: Security-focused static analysis
- **Formatter**: Consistent code formatting standards

### Quality Standards

- 📊 **90%+ Test Coverage** - Comprehensive test suite with high coverage
- 🔍 **Static Analysis** - Credo strict mode with security-focused rules
- 📝 **Documentation** - Complete module and function documentation
- 🔒 **Security Review** - All code undergoes security analysis
- ⚡ **Performance Testing** - Regular performance regression testing

### Running Quality Checks

```bash
# Run all quality checks
mix quality

# Individual quality tools
mix test --cover        # Tests with coverage
mix format             # Code formatting
mix credo --strict     # Code quality analysis
mix sobelow --config   # Security analysis
mix dialyzer          # Static type analysis
```

For detailed quality guidelines, see our [Contributing Guide](CONTRIBUTING.md).

## Contributing

We welcome contributions! Please read our [Contributing Guide](CONTRIBUTING.md) for detailed information about:

- Development setup and workflow
- Code quality standards and tools
- Testing requirements and guidelines
- Security review process
- PR submission and review process

### Quick Start for Contributors

1. Fork the repository
2. Set up development environment: `mix deps.get && mix deps.compile`
3. Run quality checks: `mix quality`
4. Create feature branch: `git checkout -b feature/amazing-feature`
5. Make changes with tests and documentation
6. Submit PR following our [Contributing Guide](CONTRIBUTING.md)

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