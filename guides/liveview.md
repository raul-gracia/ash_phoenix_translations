# LiveView Integration Guide

This guide covers real-time translation features and LiveView integration patterns for AshPhoenixTranslations.

## Overview

AshPhoenixTranslations provides seamless LiveView integration with real-time locale switching, live translation updates, and reactive UI components. This guide covers setup, patterns, and best practices for building multilingual LiveView applications.

## Setup

### Basic LiveView Configuration

Add the LiveView helpers to your web module:

```elixir
defmodule MyAppWeb do
  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {MyAppWeb.Layouts, :app}
      
      # Add translation helpers
      use AshPhoenixTranslations.LiveView
      
      unquote(html_helpers())
    end
  end
  
  def live_component do
    quote do
      use Phoenix.LiveComponent
      
      # Add translation helpers for components
      use AshPhoenixTranslations.LiveView
      
      unquote(html_helpers())
    end
  end
end
```

## Core Features

### Locale Management

#### Setting Initial Locale

```elixir
defmodule MyAppWeb.ProductLive.Index do
  use MyAppWeb, :live_view
  
  @impl true
  def mount(_params, session, socket) do
    # Set locale from session or user preferences
    socket = assign_locale(socket, session)
    
    {:ok, socket}
  end
end
```

#### Dynamic Locale Switching

```elixir
@impl true
def handle_event("change_locale", %{"locale" => locale}, socket) do
  socket =
    socket
    |> update_locale(locale)
    |> reload_translations()  # Automatically reload all translated assigns
    
  {:noreply, socket}
end
```

### Translation Assignment

#### Basic Translation Assignment

```elixir
@impl true
def mount(_params, session, socket) do
  socket = assign_locale(socket, session)
  
  # Load and translate resources
  products = MyApp.Shop.Product.list!()
  socket = assign_translations(socket, :products, products)
  
  {:ok, socket}
end
```

#### Batch Translation Assignment

```elixir
@impl true
def mount(_params, session, socket) do
  socket = assign_locale(socket, session)
  
  # Batch translate multiple resources
  socket = 
    socket
    |> assign_translations(:products, Product.list!())
    |> assign_translations(:categories, Category.list!())
    |> assign_translations(:brands, Brand.list!())
  
  {:ok, socket}
end
```

## LiveView Components

### Locale Switcher Component

```elixir
defmodule MyAppWeb.Components.LocaleSwitcher do
  use MyAppWeb, :live_component
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="locale-switcher">
      <.form for={%{}} phx-change="change_locale">
        <select name="locale" value={@current_locale}>
          <%= for {code, name} <- available_locales() do %>
            <option value={code} selected={code == @current_locale}>
              <%= name %>
            </option>
          <% end %>
        </select>
      </.form>
      
      <!-- Alternative: Flag buttons -->
      <div class="locale-flags">
        <%= for {code, flag} <- locale_flags() do %>
          <button 
            phx-click="change_locale" 
            phx-value-locale={code}
            class={if code == @current_locale, do: "active"}
          >
            <%= flag %>
          </button>
        <% end %>
      </div>
    </div>
    """
  end
  
  defp available_locales do
    [
      {"en", "English"},
      {"es", "Español"},
      {"fr", "Français"},
      {"de", "Deutsch"}
    ]
  end
  
  defp locale_flags do
    [
      {"en", "🇬🇧"},
      {"es", "🇪🇸"},
      {"fr", "🇫🇷"},
      {"de", "🇩🇪"}
    ]
  end
end
```

### Translation Status Component

```elixir
defmodule MyAppWeb.Components.TranslationStatus do
  use MyAppWeb, :live_component
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="translation-status">
      <div class="progress-bar">
        <div 
          class="progress-fill"
          style={"width: #{translation_completeness(@resource)}%"}
        />
      </div>
      <span class="status-text">
        <%= translation_completeness(@resource) %>% complete
      </span>
      
      <%= if missing_locales = missing_translations(@resource, @field) do %>
        <div class="missing-locales">
          Missing: <%= Enum.join(missing_locales, ", ") %>
        </div>
      <% end %>
    </div>
    """
  end
end
```

### Live Translation Editor

```elixir
defmodule MyAppWeb.Components.TranslationEditor do
  use MyAppWeb, :live_component
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="translation-editor">
      <.form for={@form} phx-target={@myself} phx-change="validate" phx-submit="save">
        <%= for locale <- @locales do %>
          <div class="translation-field">
            <label><%= locale_name(locale) %></label>
            
            <%= if @type == :textarea do %>
              <textarea
                name={"#{@field}_translations[#{locale}]"}
                phx-debounce="300"
                value={get_translation(@resource, @field, locale)}
              />
            <% else %>
              <input
                type="text"
                name={"#{@field}_translations[#{locale}]"}
                phx-debounce="300"
                value={get_translation(@resource, @field, locale)}
              />
            <% end %>
            
            <!-- Live preview -->
            <div class="preview" phx-update="ignore">
              Preview: <span id={"preview-#{@field}-#{locale}"}>
                <%= get_translation(@resource, @field, locale) %>
              </span>
            </div>
          </div>
        <% end %>
        
        <button type="submit">Save Translations</button>
      </.form>
    </div>
    """
  end
  
  @impl true
  def handle_event("validate", params, socket) do
    # Live validation with preview update
    form = 
      socket.assigns.resource
      |> Ash.Changeset.for_update(:update, params)
      |> to_form()
    
    {:noreply, assign(socket, :form, form)}
  end
  
  @impl true
  def handle_event("save", params, socket) do
    case update_translations(socket.assigns.resource, params) do
      {:ok, updated} ->
        send(self(), {:updated, updated})
        {:noreply, socket}
        
      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
```

## Real-time Features

### Live Translation Broadcasting

```elixir
defmodule MyAppWeb.ProductLive.Edit do
  use MyAppWeb, :live_view
  
  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      # Subscribe to translation updates
      AshPhoenixTranslations.subscribe(Product, id)
    end
    
    product = Product.get!(id)
    {:ok, assign(socket, product: product)}
  end
  
  @impl true
  def handle_info({:translation_updated, field, locale, value}, socket) do
    # Update specific translation in UI
    updated = update_translation_field(socket.assigns.product, field, locale, value)
    
    {:noreply, assign(socket, product: updated)}
  end
end
```

### Collaborative Translation

```elixir
defmodule MyAppWeb.TranslationLive.Collaborative do
  use MyAppWeb, :live_view
  
  @impl true
  def mount(%{"resource_id" => id}, _session, socket) do
    if connected?(socket) do
      # Join translation room
      Phoenix.PubSub.subscribe(MyApp.PubSub, "translations:#{id}")
      
      # Track presence
      {:ok, _} = Presence.track(
        self(),
        "translations:#{id}",
        socket.assigns.current_user.id,
        %{
          name: socket.assigns.current_user.name,
          locale: socket.assigns.locale,
          joined_at: System.system_time(:second)
        }
      )
    end
    
    resource = get_resource(id)
    presence = Presence.list("translations:#{id}")
    
    {:ok, 
     socket
     |> assign(resource: resource)
     |> assign(presence: presence)}
  end
  
  @impl true
  def handle_event("edit_field", %{"field" => field, "locale" => locale}, socket) do
    # Broadcast field lock
    Phoenix.PubSub.broadcast(
      MyApp.PubSub,
      "translations:#{socket.assigns.resource.id}",
      {:field_locked, field, locale, socket.assigns.current_user}
    )
    
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({:field_locked, field, locale, user}, socket) do
    # Show who's editing what
    {:noreply, 
     socket
     |> put_flash(:info, "#{user.name} is editing #{field} (#{locale})")
     |> assign_locked_field(field, locale, user)}
  end
end
```

## Advanced Patterns

### Lazy Loading Translations

```elixir
defmodule MyAppWeb.ProductLive.Show do
  use MyAppWeb, :live_view
  
  @impl true
  def mount(%{"id" => id}, _session, socket) do
    # Load basic data first
    product = Product.get!(id, load: [:sku, :price])
    
    # Lazy load translations
    send(self(), :load_translations)
    
    {:ok, assign(socket, product: product, translations_loaded: false)}
  end
  
  @impl true
  def handle_info(:load_translations, socket) do
    # Load translations in background
    translations = load_product_translations(socket.assigns.product)
    
    {:noreply,
     socket
     |> assign(product: translations)
     |> assign(translations_loaded: true)}
  end
end
```

### Translation Caching

```elixir
defmodule MyAppWeb.TranslationCache do
  use GenServer
  
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end
  
  def get_or_load(resource, locale) do
    GenServer.call(__MODULE__, {:get_or_load, resource, locale})
  end
  
  @impl true
  def handle_call({:get_or_load, resource, locale}, _from, state) do
    key = {resource.__struct__, resource.id, locale}
    
    case Map.get(state, key) do
      nil ->
        translated = AshPhoenixTranslations.translate(resource, locale)
        {:reply, translated, Map.put(state, key, translated)}
        
      cached ->
        {:reply, cached, state}
    end
  end
end
```

### Optimistic UI Updates

```elixir
defmodule MyAppWeb.ProductLive.QuickEdit do
  use MyAppWeb, :live_view
  
  @impl true
  def handle_event("update_translation", params, socket) do
    # Optimistically update UI
    socket = optimistic_update(socket, params)
    
    # Async save
    Task.async(fn ->
      save_translation(params)
    end)
    
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({ref, {:ok, saved}}, socket) when is_reference(ref) do
    # Confirm save
    Process.demonitor(ref, [:flush])
    {:noreply, confirm_save(socket, saved)}
  end
  
  @impl true
  def handle_info({ref, {:error, error}}, socket) when is_reference(ref) do
    # Rollback optimistic update
    Process.demonitor(ref, [:flush])
    {:noreply, rollback_update(socket, error)}
  end
end
```

## LiveView Forms

### Multi-locale Form

```elixir
defmodule MyAppWeb.ProductLive.Form do
  use MyAppWeb, :live_view
  
  @impl true
  def render(assigns) do
    ~H"""
    <.form for={@form} phx-change="validate" phx-submit="save">
      <!-- Tab navigation for locales -->
      <div class="locale-tabs">
        <%= for locale <- @locales do %>
          <button
            type="button"
            phx-click="switch_tab"
            phx-value-locale={locale}
            class={if locale == @active_locale, do: "active"}
          >
            <%= locale_name(locale) %>
            <%= if translation_complete?(@form.source, locale), do: "✓" %>
          </button>
        <% end %>
      </div>
      
      <!-- Tab content -->
      <div class="tab-content">
        <.translation_fields 
          form={@form} 
          locale={@active_locale} 
          fields={@translatable_fields}
        />
      </div>
      
      <!-- Quick locale copy -->
      <div class="locale-actions">
        <button type="button" phx-click="copy_from" phx-value-source="en">
          Copy from English
        </button>
      </div>
      
      <button type="submit">Save All Translations</button>
    </.form>
    """
  end
  
  defp translation_fields(assigns) do
    ~H"""
    <%= for field <- @fields do %>
      <div class="field">
        <label><%= humanize(field) %> (<%= @locale %>)</label>
        <input
          type="text"
          name={"product[#{field}_translations][#{@locale}]"}
          value={get_field_translation(@form, field, @locale)}
          phx-debounce="300"
        />
      </div>
    <% end %>
    """
  end
end
```

## Performance Optimization

### Efficient Translation Loading

```elixir
defmodule MyAppWeb.Helpers.TranslationLoader do
  def preload_translations(socket, resources) do
    # Batch load translations
    locale = socket.assigns.locale
    
    translated = 
      resources
      |> AshPhoenixTranslations.translate_all(locale)
      |> Map.new(fn r -> {r.id, r} end)
    
    assign(socket, :translated_resources, translated)
  end
  
  def get_translated(socket, resource_id) do
    Map.get(socket.assigns.translated_resources, resource_id)
  end
end
```

### Translation Streams

```elixir
defmodule MyAppWeb.ProductLive.Index do
  use MyAppWeb, :live_view
  
  @impl true
  def mount(_params, session, socket) do
    socket = assign_locale(socket, session)
    
    # Stream translations for large datasets
    socket =
      socket
      |> stream(:products, Product.list!())
      |> stream_translations(:products, socket.assigns.locale)
    
    {:ok, socket}
  end
  
  defp stream_translations(socket, stream_name, locale) do
    # Process translations in chunks
    update(socket, stream_name, fn stream ->
      stream
      |> Stream.chunk_every(10)
      |> Stream.map(&translate_chunk(&1, locale))
      |> Stream.flat_map(& &1)
    end)
  end
end
```

## Testing LiveView Translations

```elixir
defmodule MyAppWeb.ProductLiveTest do
  use MyAppWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  
  test "changes locale dynamically", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/products")
    
    # Initial locale
    assert has_element?(view, "h1", "Products")
    
    # Change locale
    view
    |> element("[phx-change='change_locale']")
    |> render_change(%{locale: "es"})
    
    # Verify translation
    assert has_element?(view, "h1", "Productos")
  end
  
  test "updates translations in real-time", %{conn: conn} do
    product = create_product()
    {:ok, view, _html} = live(conn, ~p"/products/#{product.id}/edit")
    
    # Update translation
    view
    |> form("#translation-form")
    |> render_change(%{
      product: %{
        name_translations: %{
          es: "Nuevo Nombre"
        }
      }
    })
    
    # Verify live preview
    assert has_element?(view, "#preview-name-es", "Nuevo Nombre")
  end
end
```

## Best Practices

1. **Preload Translations**: Load translations upfront for better performance
2. **Use Streams**: For large datasets, use LiveView streams with translation chunks
3. **Cache Wisely**: Implement translation caching for frequently accessed content
4. **Debounce Updates**: Use phx-debounce for translation form fields
5. **Optimistic Updates**: Update UI immediately, save asynchronously
6. **Progressive Enhancement**: Load core content first, translations second

## Troubleshooting

### Common Issues

**Locale Not Persisting**
- Check session configuration
- Verify locale assignment in mount/3
- Ensure locale is included in live_session

**Translation Updates Not Reflecting**
- Verify PubSub subscription
- Check translation reload after locale change
- Ensure assigns are properly updated

**Performance Issues**
- Implement translation caching
- Use batch loading for multiple resources
- Consider lazy loading for large datasets