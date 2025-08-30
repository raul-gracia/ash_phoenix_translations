<library_design>
  <name>AshPhoenixTranslations</name>
  <description>A powerful Ash Framework extension that seamlessly integrates translation capabilities into Ash resources, providing a unified, policy-aware translation system for Phoenix applications with support for multiple backends and dynamic locale switching.</description>

  <features>
    <feature>**Attribute-level translations**: Define translatable attributes directly in Ash resources with automatic validation and type casting for different locales</feature>
    <feature>**Policy-aware translations**: Leverage Ash policies to control which translations users can view/edit based on roles, permissions, or custom logic</feature>
    <feature>**Multi-backend support**: Pluggable architecture supporting Gettext, database storage (via Ash.DataLayer), Redis, or custom backends</feature>
    <feature>**Lazy-loading translations**: Optimize performance by loading translations only when needed, with configurable caching strategies</feature>
    <feature>**Nested translations**: Support for translating embedded schemas and relationships within Ash resources</feature>
    <feature>**Bulk operations**: Import/export translations via CSV, JSON, or XLIFF formats with validation</feature>
    <feature>**Live translation editing**: Real-time translation updates via Phoenix LiveView integration</feature>
    <feature>**Fallback chains**: Configure locale fallback hierarchies (e.g., en-GB → en → default)</feature>
    <feature>**Translation versioning**: Track translation changes over time with optional audit logging</feature>
    <feature>**GraphQL/JSON:API support**: Automatic translation exposure through Ash's API extensions</feature>
  </features>

  <interface>
    <translatable_attributes>
```elixir
# In your Ash resource
defmodule MyApp.Product do
  use Ash.Resource,
    extensions: [AshPhoenixTranslations.Resource]

  attributes do
    uuid_primary_key :id
    
    # Define translatable attributes
    translatable_attribute :name, :string do
      locales [:en, :es, :fr, :de]
      required [:en]  # English required
      validation :length, min: 1, max: 255
    end
    
    translatable_attribute :description, :text do
      locales [:en, :es, :fr, :de]
      markdown true  # Support markdown in translations
      fallback :en   # Fallback to English if locale missing
    end
    
    attribute :price, :decimal
    attribute :sku, :string
  end

  translations do
    # Configure translation behavior
    backend :database  # or :gettext, :redis, etc.
    
    # Define who can edit translations
    policy :update_translations do
      authorize_if actor_attribute(:role) == :translator
      authorize_if actor_attribute(:role) == :admin
    end
    
    # Audit translations
    audit_changes true
    
    # Cache settings
    cache_ttl 3600  # 1 hour
  end
end
</translatable_attributes>

<accessing_translations>



# In Phoenix controllers/LiveViews
defmodule MyAppWeb.ProductController do
  use MyAppWeb, :controller
  
  def show(conn, %{"id" => id}) do
    # Automatically uses conn's locale
    product = MyApp.Product
      |> Ash.get!(id)
      |> AshPhoenixTranslations.translate(conn)
    
    render(conn, "show.html", product: product)
  end
  
  def index(conn, _params) do
    # Translate multiple resources
    products = MyApp.Product
      |> Ash.read!()
      |> AshPhoenixTranslations.translate_all(conn)
    
    render(conn, "index.html", products: products)
  end
end

# In templates (automatic helper functions)
<%= t(@product, :name) %>
<%= t(@product, :description) %>

# Or with explicit locale
<%= t(@product, :name, locale: :es) %>

# In LiveView with reactive translations
defmodule MyAppWeb.ProductLive do
  use MyAppWeb, :live_view
  
  def mount(%{"id" => id}, _session, socket) do
    product = MyApp.Product
      |> Ash.get!(id)
      |> AshPhoenixTranslations.live_translate(socket)
    
    {:ok, assign(socket, product: product)}
  end
  
  def handle_event("change_locale", %{"locale" => locale}, socket) do
    # Dynamically update translations
    socket = AshPhoenixTranslations.update_locale(socket, locale)
    {:noreply, socket}
  end
end
</accessing_translations>

<managing_translations>
# Via Ash Admin integration
defmodule MyApp.Admin do
  use AshAdmin,
    apis: [MyApp.Api],
    translations: [
      enabled: true,
      locales: [:en, :es, :fr, :de],
      editor_roles: [:admin, :translator]
    ]
end

# Programmatic management
MyApp.Product
|> Ash.get!(product_id)
|> AshPhoenixTranslations.update_translation(:name, :es, "Producto")
|> AshPhoenixTranslations.update_translation(:description, :es, "Descripción...")
|> Ash.update!()

# Bulk import
AshPhoenixTranslations.import_csv(MyApp.Product, "translations.csv")

# Export current translations
AshPhoenixTranslations.export_json(MyApp.Product, locales: [:en, :es])
</managing_translations>

</interface>
  <installation>
    <step>**Add dependency to mix.exs**:
```elixir
def deps do
  [
    {:ash_phoenix_translations, "~> 1.0"},
    # Optional backends
    {:gettext, "~> 0.20"},  # If using Gettext backend
    {:redix, "~> 1.1"}      # If using Redis backend
  ]
end
```
    </step>
    <step>**Run dependency installation**:
```bash
mix deps.get
mix deps.compile
```
    </step>
    <step>**Generate initial configuration**:
```bash
mix ash_phoenix_translations.install
```
    </step>
    <step>**Run migrations if using database backend**:
```bash
mix ecto.create
mix ecto.migrate
```
    </step>
  </installation>
  <configuration>
    <backend>
```elixir
# config/config.exs
config :ash_phoenix_translations,
  default_backend: :database,
  backends: [
    database: [
      repo: MyApp.Repo,
      table: "translations",
      schema: AshPhoenixTranslations.Storage.Database
    ],
    gettext: [
      backend: MyApp.Gettext,
      priv: "priv/gettext"
    ],
    redis: [
      host: "localhost",
      port: 6379,
      pool_size: 10
    ]
  ]
```
    </backend>

    <locale>

    # config/config.exs
config :ash_phoenix_translations,
  default_locale: :en,
  available_locales: [:en, :es, :fr, :de, :ja],
  fallback_chains: %{
    "en-US" => [:en],
    "en-GB" => [:en],
    "es-MX" => [:es, :en],
    "fr-CA" => [:fr, :en]
  },
  locale_resolver: AshPhoenixTranslations.LocaleResolver.Header,
  # or .Cookie, .Session, .Subdomain, .Custom
  
  # Performance settings
  cache_adapter: AshPhoenixTranslations.Cache.ETS,
  cache_ttl: 3600,
  preload_translations: true

  </locale>

<phoenix_integration>

# lib/my_app_web.ex
def controller do
  quote do
    use Phoenix.Controller, namespace: MyAppWeb
    import AshPhoenixTranslations.Controller
    # Adds translation helpers to all controllers
  end
end

def view do
  quote do
    use Phoenix.View, root: "lib/my_app_web/templates"
    import AshPhoenixTranslations.Helpers
    # Adds t/2, t/3 helpers to all views
  end
end

# In your router pipeline
pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session
  plug AshPhoenixTranslations.Plug.SetLocale
  plug AshPhoenixTranslations.Plug.LoadTranslations
end

</phoenix_integration>

<ash_specific>

# In your Ash API
defmodule MyApp.Api do
  use Ash.Api,
    extensions: [AshPhoenixTranslations.Api]
  
  translations do
    auto_translate_reads true
    translate_filters true
    translate_sorts true
  end
end

# Global settings for all resources
config :ash_phoenix_translations,
  auto_generate_changeset_errors: true,
  translate_ash_errors: true,
  error_translation_backend: :gettext

  </interface>
  <installation>
    <step>**Add dependency to mix.exs**:
```elixir
def deps do
  [
    {:ash_phoenix_translations, "~> 1.0"},
    # Optional backends
    {:gettext, "~> 0.20"},  # If using Gettext backend
    {:redix, "~> 1.1"}      # If using Redis backend
  ]
end
```
    </step>
    <step>**Run dependency installation**:
```bash
mix deps.get
mix deps.compile
```
    </step>
    <step>**Generate initial configuration**:
```bash
mix ash_phoenix_translations.install
```
    </step>
    <step>**Run migrations if using database backend**:
```bash
mix ecto.create
mix ecto.migrate
```
    </step>
  </installation>
  <configuration>
    <backend>
```elixir
# config/config.exs
config :ash_phoenix_translations,
  default_backend: :database,
  backends: [
    database: [
      repo: MyApp.Repo,
      table: "translations",
      schema: AshPhoenixTranslations.Storage.Database
    ],
    gettext: [
      backend: MyApp.Gettext,
      priv: "priv/gettext"
    ],
    redis: [
      host: "localhost",
      port: 6379,
      pool_size: 10
    ]
  ]
```
    </backend>

    </configuration>
  <advantages>
    <advantage>**Deep Ash Integration**: Unlike Phoenix's default Gettext-based approach, AshPhoenixTranslations treats translations as first-class citizens within your domain model. Translatable attributes are defined at the resource level with full validation, authorization, and business logic support.</advantage>
    <advantage>**Policy-Based Access Control**: Leverages Ash's powerful policy engine to control who can view and edit translations. This goes far beyond simple role checks - you can implement complex rules like "translators can only edit their assigned languages" or "draft translations require approval from senior translators".</advantage>

<advantage>**Unified Data Layer**: Store translations alongside your domain data using Ash's data layer abstraction. This means translations can live in PostgreSQL, MongoDB, or any supported data store, with automatic relationship handling and query optimization.</advantage>

<advantage>**Performance Optimization**: Built-in caching, lazy loading, and batch fetching of translations. The library intelligently preloads only the translations needed for the current request's locale, reducing memory usage and query overhead compared to loading all Gettext files.</advantage>

<advantage>**API-First Design**: Automatic exposure of translations through GraphQL and JSON:API without additional configuration. Frontend applications can query specific locales, request multiple translations in one request, and even subscribe to translation changes via GraphQL subscriptions.</advantage>

<advantage>**LiveView Reactivity**: Native Phoenix LiveView integration enables real-time locale switching without page reloads, live translation editing with instant preview, and collaborative translation workflows where multiple translators can work simultaneously.</advantage>

<advantage>**Type Safety**: Compile-time checking of translation keys and locales. The library generates helper functions based on your resource definitions, catching typos and missing translations during compilation rather than runtime.</advantage>

<advantage>**Audit Trail**: Built-in versioning and audit logging for translations, tracking who changed what and when. This is crucial for compliance and quality control in multi-language applications.</advantage>

<advantage>**Developer Experience**: Clean, declarative syntax that follows Ash conventions. Translations are defined alongside attributes, making the codebase more maintainable and reducing the cognitive overhead of managing separate translation files.</advantage>

<advantage>**Migration Path**: Provides tools to migrate from existing Gettext translations, allowing gradual adoption without rewriting your entire i18n setup.</advantage>
</advantages>
</library_design>
