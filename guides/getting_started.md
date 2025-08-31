# Getting Started with AshPhoenixTranslations

This guide will walk you through setting up and using AshPhoenixTranslations in your Phoenix application.

## Prerequisites

- Elixir 1.14 or later
- Phoenix 1.7 or later  
- Ash 3.0 or later
- PostgreSQL (for database backend)

## Installation

### Step 1: Add the Dependency

Add `ash_phoenix_translations` to your `mix.exs`:

```elixir
defp deps do
  [
    {:ash_phoenix_translations, "~> 1.0.0"}
  ]
end
```

Then fetch dependencies:

```bash
mix deps.get
```

### Step 2: Run the Installer

```bash
mix ash_phoenix_translations.install
```

You'll be prompted to choose a backend:
- `database` (recommended) - Stores translations in JSONB columns
- `gettext` - Uses Phoenix's Gettext
- `redis` - Stores in Redis key-value store

### Step 3: Run Migrations (Database Backend)

If you chose the database backend:

```bash
mix ecto.migrate
```

## Basic Usage

### Creating a Translatable Resource

Let's create a `Product` resource with translatable fields:

```elixir
defmodule MyApp.Shop.Product do
  use Ash.Resource,
    domain: MyApp.Shop,
    extensions: [AshPhoenixTranslations]
  
  translations do
    # Define translatable fields
    translatable_attribute :name,
      locales: [:en, :es, :fr, :de],
      required: [:en]  # English is required
    
    translatable_attribute :description,
      locales: [:en, :es, :fr, :de],
      translate: true  # Adds calculated attributes
    
    # Storage configuration
    backend :database
    cache_ttl 3600  # Cache for 1 hour
    
    # Optional features
    audit_changes true  # Track who changed translations
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
      accept [:sku, :price, :stock_quantity]
      # Translation fields are automatically accepted
    end
    
    update :update do
      accept [:price, :stock_quantity]
      # Translation fields are automatically accepted
    end
  end
  
  code_interface do
    define :create
    define :get_by_id, args: [:id], action: :read
    define :list
    define :update
  end
end
```

### Working with Translations in Code

#### Creating Records

```elixir
# Create a product with translations
{:ok, product} = MyApp.Shop.Product.create(%{
  sku: "LAPTOP-001",
  price: Decimal.new("999.99"),
  stock_quantity: 10,
  name_translations: %{
    en: "Gaming Laptop",
    es: "Portátil para Juegos",
    fr: "Ordinateur Portable Gaming",
    de: "Gaming-Laptop"
  },
  description_translations: %{
    en: "High-performance gaming laptop with RTX 4080",
    es: "Portátil gaming de alto rendimiento con RTX 4080",
    fr: "Ordinateur portable gaming haute performance avec RTX 4080"
  }
})
```

#### Reading Translated Content

```elixir
# Get a product
{:ok, product} = MyApp.Shop.Product.get_by_id(product_id)

# Access raw translations
product.name_translations.en  # => "Gaming Laptop"
product.name_translations.es  # => "Portátil para Juegos"

# Get translated version for a specific locale
translated = AshPhoenixTranslations.translate(product, :es)
translated.name  # => "Portátil para Juegos"  (from calculation)
translated.description  # => "Portátil gaming de alto rendimiento..."
```

#### Updating Translations

```elixir
# Update specific translations
{:ok, updated} = MyApp.Shop.Product.update(product, %{
  name_translations: %{
    en: "Gaming Laptop Pro",
    es: "Portátil Gaming Pro"
    # Other locales remain unchanged
  }
})

# Partial updates merge with existing translations
{:ok, updated} = MyApp.Shop.Product.update(product, %{
  description_translations: %{
    de: "Hochleistungs-Gaming-Laptop mit RTX 4080"
  }
})
```

## Phoenix Integration

### Setting Up Locale Detection

Add to your router:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    
    # Add translation plugs
    plug AshPhoenixTranslations.Plugs.SetLocale,
      strategies: [:param, :session, :cookie, :header],
      fallback: "en",
      supported: ["en", "es", "fr", "de"]
    
    plug AshPhoenixTranslations.Plugs.LoadTranslations,
      resources: [MyApp.Shop.Product],
      cache: true
  end
  
  # ... routes
end
```

### Using in Controllers

```elixir
defmodule MyAppWeb.ProductController do
  use MyAppWeb, :controller
  import AshPhoenixTranslations.Controller
  
  def index(conn, _params) do
    products = MyApp.Shop.Product.list!()
    
    # Translate all products to current locale
    products = with_locale(conn, products)
    
    render(conn, :index, products: products)
  end
  
  def show(conn, %{"id" => id}) do
    product = MyApp.Shop.Product.get_by_id!(id)
    
    # Translate single product
    product = with_locale(conn, product)
    
    render(conn, :show, product: product)
  end
  
  def change_locale(conn, %{"locale" => locale}) do
    conn
    |> set_locale(locale)
    |> redirect(to: ~p"/products")
  end
end
```

### Using in Templates

Import helpers in your HTML helpers:

```elixir
defmodule MyAppWeb do
  def html do
    quote do
      use Phoenix.Component
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]
      
      unquote(html_helpers())
      
      # Add translation helpers
      import AshPhoenixTranslations.Helpers
    end
  end
end
```

Use in templates:

```heex
<%!-- products/index.html.heex --%>
<h1><%= gettext("Products") %></h1>

<%!-- Language switcher --%>
<%= language_switcher(@conn, MyApp.Shop.Product) %>

<div class="products">
  <%= for product <- @products do %>
    <div class="product">
      <%!-- Translated fields --%>
      <h2><%= t(product, :name) %></h2>
      <p><%= t(product, :description) %></p>
      
      <%!-- Translation status --%>
      <%= translation_status(product, :description) %>
      
      <%!-- Regular fields --%>
      <span class="price">$<%= product.price %></span>
      <span class="stock">Stock: <%= product.stock_quantity %></span>
    </div>
  <% end %>
</div>
```

### Translation Forms

```heex
<%!-- products/edit.html.heex --%>
<.form for={@form} action={~p"/products/#{@product.id}"}>
  <%!-- Regular fields --%>
  <.input field={@form[:sku]} label="SKU" />
  <.input field={@form[:price]} label="Price" type="number" step="0.01" />
  
  <%!-- Translation fields --%>
  <h3>Name Translations</h3>
  <%= for locale <- [:en, :es, :fr, :de] do %>
    <%= translation_input @form, :name, locale %>
  <% end %>
  
  <h3>Description Translations</h3>
  <%= for locale <- [:en, :es, :fr, :de] do %>
    <%= translation_input @form, :description, locale, type: :textarea %>
  <% end %>
  
  <%!-- Show completeness --%>
  <div class="translation-stats">
    Completeness: <%= translation_completeness(@product) %>%
  </div>
  
  <.button type="submit">Save Product</.button>
</.form>
```

## LiveView Integration

### Basic LiveView Setup

```elixir
defmodule MyAppWeb.ProductLive.Index do
  use MyAppWeb, :live_view
  use AshPhoenixTranslations.LiveView
  
  @impl true
  def mount(_params, session, socket) do
    # Set locale from session
    socket = assign_locale(socket, session)
    
    # Load and translate products
    products = MyApp.Shop.Product.list!()
    socket = assign_translations(socket, :products, products)
    
    {:ok, socket}
  end
  
  @impl true
  def handle_params(params, _url, socket) do
    # Handle locale changes from URL params
    socket = 
      if params["locale"] do
        update_locale(socket, params["locale"])
      else
        socket
      end
    
    {:noreply, socket}
  end
  
  @impl true
  def handle_event("change_locale", %{"locale" => locale}, socket) do
    socket = 
      socket
      |> update_locale(locale)
      |> reload_translations()  # Reload all translated assigns
    
    {:noreply, socket}
  end
end
```

### LiveView Template

```heex
<%!-- live/product_live/index.html.heex --%>
<div>
  <%!-- Locale switcher component --%>
  <.locale_switcher socket={@socket} />
  
  <%!-- Products grid --%>
  <div class="grid grid-cols-3 gap-4">
    <%= for product <- @products do %>
      <.product_card product={product} locale={@locale} />
    <% end %>
  </div>
</div>
```

### LiveView Form Component

```elixir
defmodule MyAppWeb.ProductLive.FormComponent do
  use MyAppWeb, :live_component
  use AshPhoenixTranslations.LiveView
  
  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form for={@form} phx-target={@myself} phx-change="validate" phx-submit="save">
        <%!-- Translation fields with live preview --%>
        <div class="space-y-4">
          <.translation_field 
            form={@form} 
            field={:name} 
            locales={[:en, :es, :fr, :de]}
          />
          
          <.translation_field 
            form={@form} 
            field={:description} 
            locales={[:en, :es, :fr, :de]}
            type="textarea"
          />
        </div>
        
        <%!-- Translation progress --%>
        <.translation_progress resource={@product} />
        
        <%!-- Preview in different locales --%>
        <.translation_preview 
          resource={@product} 
          field={:description}
          locales={[:en, :es, :fr, :de]}
        />
        
        <.button type="submit">Save</.button>
      </.form>
    </div>
    """
  end
  
  @impl true
  def handle_event("validate", %{"product" => params}, socket) do
    # Validate translations
    form = 
      socket.assigns.product
      |> MyApp.Shop.Product.changeset(params)
      |> to_form()
    
    {:noreply, assign(socket, :form, form)}
  end
  
  @impl true
  def handle_event("save", %{"product" => params}, socket) do
    case MyApp.Shop.Product.update(socket.assigns.product, params) do
      {:ok, product} ->
        # Broadcast translation update
        broadcast_translation_update(product, :name, :es, params["name_translations"]["es"])
        
        {:noreply, 
         socket
         |> put_flash(:info, "Product updated successfully")
         |> push_navigate(to: socket.assigns.navigate)}
      
      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
```

## Best Practices

### 1. Always Provide a Default Locale

```elixir
translations do
  translatable_attribute :name,
    locales: [:en, :es, :fr],
    required: [:en]  # Always require at least one locale
end
```

### 2. Use Caching Wisely

```elixir
translations do
  cache_ttl 3600  # 1 hour for frequently accessed content
  # cache_ttl 86400  # 24 hours for rarely changing content
end
```

### 3. Validate Translations

Run validation regularly:

```bash
# In CI/CD pipeline
mix ash_phoenix_translations.validate --all --strict
```

### 4. Handle Missing Translations Gracefully

```elixir
# Always provide fallbacks
<%= t(@product, :tagline, fallback: "No tagline available") %>

# Or use the default locale as fallback
<%= t(@product, :description) || t(@product, :description, locale: :en) %>
```

### 5. Organize Translation Workflows

```elixir
# Separate concerns
defmodule MyApp.TranslationService do
  def complete?(resource) do
    AshPhoenixTranslations.translation_completeness(resource) == 100.0
  end
  
  def missing_locales(resource, field) do
    all = [:en, :es, :fr, :de]
    existing = AshPhoenixTranslations.available_locales(resource, field)
    all -- existing
  end
  
  def needs_review?(resource) do
    # Your business logic
  end
end
```

## Troubleshooting

### Common Issues

#### Translations Not Showing

1. Check locale is being set correctly:
```elixir
IO.inspect(conn.assigns[:locale])
```

2. Verify translations exist:
```elixir
IO.inspect(product.name_translations)
```

3. Check cache isn't stale:
```elixir
AshPhoenixTranslations.Cache.invalidate_resource(Product, product_id)
```

#### Performance Issues

1. Enable caching:
```elixir
translations do
  cache_ttl 3600
end
```

2. Warm cache on startup:
```elixir
# In application.ex
AshPhoenixTranslations.Cache.warm(Product, [:name, :description], [:en, :es])
```

3. Use batch operations:
```elixir
# Instead of translating one by one
products = Enum.map(products, &AshPhoenixTranslations.translate(&1, locale))

# Use batch translation
products = AshPhoenixTranslations.translate_all(products, locale)
```

## Next Steps

- Read the [Policy Guide](policies.md) to learn about access control
- See [Import/Export Guide](import_export.md) for bulk operations
- Check [Backend Guide](backends.md) for backend-specific configuration
- Explore [LiveView Guide](liveview.md) for real-time features