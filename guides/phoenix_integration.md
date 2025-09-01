# Phoenix Integration Guide

This guide covers integrating AshPhoenixTranslations with Phoenix applications, including controllers, views, templates, and LiveView.

## Router Setup

### Basic Configuration

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
    
    # Translation plugs
    plug AshPhoenixTranslations.Plugs.SetLocale,
      strategies: [:param, :session, :cookie, :header],
      fallback: "en",
      supported: ["en", "es", "fr", "de"]
    
    plug AshPhoenixTranslations.Plugs.LoadTranslations,
      resources: [MyApp.Catalog.Product, MyApp.Blog.Post]
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug AshPhoenixTranslations.JsonApi.LocalePlug
  end
  
  scope "/", MyAppWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/change-locale/:locale", PageController, :change_locale
    
    resources "/products", ProductController
    resources "/posts", PostController
  end
  
  # LiveView routes
  scope "/", MyAppWeb do
    pipe_through :browser
    
    live "/live-products", ProductLive.Index, :index
    live "/live-products/:id", ProductLive.Show, :show
  end
end
```

### Locale Resolution Strategies

The `SetLocale` plug supports multiple strategies for determining the user's locale:

```elixir
plug AshPhoenixTranslations.Plugs.SetLocale,
  strategies: [:param, :session, :cookie, :header, :custom],
  fallback: "en",
  supported: ["en", "es", "fr", "de"],
  custom: fn conn ->
    # Custom locale resolution logic
    case get_user_preference(conn) do
      nil -> nil
      locale -> to_string(locale)
    end
  end
```

**Strategy Priority** (first match wins):
1. `:param` - URL parameter `?locale=es`
2. `:session` - Phoenix session `:locale` key
3. `:cookie` - Browser cookie `locale`
4. `:header` - `Accept-Language` header
5. `:custom` - Custom function

## Controller Integration

### Basic Controller Usage

```elixir
defmodule MyAppWeb.ProductController do
  use MyAppWeb, :controller
  import AshPhoenixTranslations.Controller
  
  alias MyApp.Catalog

  def index(conn, _params) do
    products = Catalog.list_products!()
    
    # Translate all products to current locale
    products = with_locale(conn, products)
    
    render(conn, :index, products: products)
  end

  def show(conn, %{"id" => id}) do
    product = Catalog.get_product!(id)
    
    # Translate single product
    product = with_locale(conn, product)
    
    render(conn, :show, product: product)
  end

  def edit(conn, %{"id" => id}) do
    product = Catalog.get_product!(id)
    changeset = Catalog.change_product(product)
    
    render(conn, :edit, product: product, changeset: changeset)
  end

  def update(conn, %{"id" => id, "product" => product_params}) do
    product = Catalog.get_product!(id)
    
    case Catalog.update_product(product, product_params) do
      {:ok, product} ->
        conn
        |> put_flash(:info, "Product updated successfully.")
        |> redirect(to: ~p"/products/#{product}")

      {:error, changeset} ->
        # Handle translation validation errors
        translation_errors = translation_errors(changeset)
        
        conn
        |> put_flash(:error, "Please check the form for errors.")
        |> render(:edit, product: product, changeset: changeset, 
                   translation_errors: translation_errors)
    end
  end

  def change_locale(conn, %{"locale" => locale}) do
    if locale_supported?(MyApp.Catalog.Product, locale) do
      conn
      |> set_locale(locale)
      |> put_flash(:info, "Language changed to #{locale_name(locale)}")
      |> redirect(to: get_referrer(conn) || ~p"/products")
    else
      conn
      |> put_flash(:error, "Unsupported locale")
      |> redirect(to: ~p"/products")
    end
  end
  
  defp get_referrer(conn) do
    Plug.Conn.get_req_header(conn, "referer") |> List.first()
  end
end
```

### Advanced Controller Patterns

```elixir
defmodule MyAppWeb.ProductController do
  use MyAppWeb, :controller
  import AshPhoenixTranslations.Controller

  # Temporary locale switching
  def preview(conn, %{"id" => id, "locale" => locale}) do
    product = Catalog.get_product!(id)
    
    # Temporarily switch locale for preview
    preview_product = with_locale conn, locale do
      AshPhoenixTranslations.translate(product, locale)
    end
    
    render(conn, :preview, product: preview_product, locale: locale)
  end

  # Bulk translation operations
  def export_translations(conn, %{"format" => format}) do
    products = Catalog.list_products!()
    current_locale = get_locale(conn)
    
    case format do
      "csv" ->
        csv_data = build_csv_export(products, current_locale)
        
        conn
        |> put_resp_content_type("text/csv")
        |> put_resp_header("content-disposition", "attachment; filename=\"products_#{current_locale}.csv\"")
        |> send_resp(200, csv_data)
      
      "json" ->
        json_data = build_json_export(products, current_locale)
        json(conn, json_data)
    end
  end
end
```

## View and Template Integration

### View Helpers Setup

```elixir
defmodule MyAppWeb do
  def html do
    quote do
      use Phoenix.Component
      
      # Import Phoenix built-ins
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]
      
      # Import your app's custom helpers
      unquote(html_helpers())
      
      # Import translation helpers
      import AshPhoenixTranslations.Helpers
    end
  end
  
  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {MyAppWeb.Layouts, :app}

      # Import translation helpers for LiveView
      use AshPhoenixTranslations.LiveView
      
      unquote(html_helpers())
    end
  end
end
```

### Template Usage

#### Basic Translation Templates

```heex
<%!-- products/index.html.heex --%>
<div class="products">
  <div class="header">
    <h1><%= gettext("Products") %></h1>
    
    <%!-- Language switcher --%>
    <%= language_switcher(@conn, MyApp.Catalog.Product, class: "locale-switcher") %>
  </div>

  <div class="product-grid">
    <%= for product <- @products do %>
      <div class="product-card">
        <%!-- Translated content --%>
        <h3><%= t(product, :name) %></h3>
        <p><%= t(product, :description) %></p>
        
        <%!-- Fallback handling --%>
        <p class="tagline">
          <%= t(product, :tagline, fallback: gettext("No tagline available")) %>
        </p>
        
        <%!-- Non-translated content --%>
        <div class="metadata">
          <span class="price">$<%= product.price %></span>
          <span class="sku">SKU: <%= product.sku %></span>
        </div>
        
        <%!-- Translation status --%>
        <div class="translation-info">
          <%= translation_status(product, :description, locales: [:en, :es, :fr]) %>
          <span class="completeness">
            <%= translation_completeness(product) %>% complete
          </span>
        </div>
        
        <.link navigate={~p"/products/#{product.id}"} class="btn btn-primary">
          <%= gettext("View Details") %>
        </.link>
      </div>
    <% end %>
  </div>
</div>
```

#### Translation Form Templates

```heex
<%!-- products/form.html.heex --%>
<.form :let={f} for={@changeset} action={@action}>
  <%!-- Regular fields --%>
  <div class="field">
    <.input field={f[:sku]} label="SKU" />
  </div>
  
  <div class="field">
    <.input field={f[:price]} label="Price" type="number" step="0.01" />
  </div>
  
  <%!-- Translation fields --%>
  <div class="translation-section">
    <h3><%= gettext("Name Translations") %></h3>
    <div class="translation-fields">
      <%= for locale <- [:en, :es, :fr, :de] do %>
        <div class="translation-field" data-locale={locale}>
          <%= translation_input f, :name, locale, 
                label: gettext("Name") <> " (#{locale_name(locale)})",
                required: locale == :en,
                placeholder: gettext("Enter product name") %>
          
          <%!-- Show character count --%>
          <small class="char-count" 
                 data-field="name" 
                 data-locale={locale}>
          </small>
        </div>
      <% end %>
    </div>
  </div>

  <div class="translation-section">
    <h3><%= gettext("Description Translations") %></h3>
    <div class="translation-fields">
      <%= for locale <- [:en, :es, :fr, :de] do %>
        <div class="translation-field" data-locale={locale}>
          <%= translation_input f, :description, locale, 
                type: :textarea,
                label: gettext("Description") <> " (#{locale_name(locale)})",
                rows: 4 %>
        </div>
      <% end %>
    </div>
  </div>
  
  <%!-- Translation progress indicator --%>
  <div class="translation-progress">
    <h4><%= gettext("Translation Progress") %></h4>
    <div class="progress-bar">
      <div class="progress" style={"width: #{translation_completeness(@product || %{})}%"}>
        <%= translation_completeness(@product || %{}) %>%
      </div>
    </div>
  </div>
  
  <%!-- Translation errors --%>
  <%= if assigns[:translation_errors] && @translation_errors != [] do %>
    <div class="alert alert-danger">
      <h5><%= gettext("Translation Errors") %></h5>
      <ul>
        <%= for {field, message} <- @translation_errors do %>
          <li><strong><%= humanize(field) %></strong>: <%= message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>
  
  <div class="actions">
    <.button type="submit"><%= gettext("Save Product") %></.button>
    <.link navigate={@cancel_path} class="btn btn-secondary">
      <%= gettext("Cancel") %>
    </.link>
  </div>
</.form>

<script>
// Character counting for translation fields
document.addEventListener('DOMContentLoaded', function() {
  const translationInputs = document.querySelectorAll('[data-field][data-locale]');
  
  translationInputs.forEach(function(counter) {
    const field = counter.dataset.field;
    const locale = counter.dataset.locale;
    const input = document.querySelector(`input[name*="${field}_translations[${locale}]"], textarea[name*="${field}_translations[${locale}]"]`);
    
    if (input) {
      function updateCount() {
        counter.textContent = `${input.value.length} characters`;
      }
      
      input.addEventListener('input', updateCount);
      updateCount(); // Initial count
    }
  });
});
</script>
```

## LiveView Integration

### Basic LiveView Setup

```elixir
defmodule MyAppWeb.ProductLive.Index do
  use MyAppWeb, :live_view
  use AshPhoenixTranslations.LiveView

  alias MyApp.Catalog
  
  @impl true
  def mount(_params, session, socket) do
    # Set locale from session/params
    socket = assign_locale(socket, session)
    
    if connected?(socket) do
      # Subscribe to translation updates
      subscribe_to_translations(MyApp.Catalog.Product)
    end
    
    # Load and translate products
    products = Catalog.list_products!()
    socket = assign_translations(socket, :products, products)
    
    socket =
      socket
      |> assign(:page_title, "Products")
      |> assign(:filters, %{})
    
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    # Handle locale changes from URL
    socket = 
      case params["locale"] do
        nil -> socket
        locale -> update_locale(socket, locale)
      end
    
    {:noreply, socket}
  end

  @impl true
  def handle_event("change_locale", %{"locale" => locale}, socket) do
    socket = 
      socket
      |> update_locale(locale)
      |> reload_translations()
      |> put_flash(:info, "Language changed to #{locale_name(locale)}")
    
    {:noreply, socket}
  end

  @impl true  
  def handle_event("filter", %{"filter" => filter_params}, socket) do
    # Apply filters and retranslate
    products = apply_filters_and_list(filter_params)
    socket = assign_translations(socket, :products, products)
    
    {:noreply, assign(socket, :filters, filter_params)}
  end

  # Handle translation updates from other users
  @impl true
  def handle_info({:translation_updated, resource_id, field, locale, value}, socket) do
    socket = handle_translation_update(socket, resource_id, field, locale, value)
    {:noreply, socket}
  end
  
  defp apply_filters_and_list(filters) do
    # Your filtering logic here
    Catalog.list_products!()
  end
end
```

### Advanced LiveView Components

```elixir
defmodule MyAppWeb.ProductLive.TranslationForm do
  use MyAppWeb, :live_component
  use AshPhoenixTranslations.LiveView

  @impl true
  def render(assigns) do
    ~H"""
    <div class="translation-form">
      <.form 
        for={@form} 
        phx-target={@myself}
        phx-change="validate" 
        phx-submit="save"
      >
        <%!-- Tab navigation for locales --%>
        <div class="locale-tabs">
          <%= for locale <- @locales do %>
            <button
              type="button"
              class={["tab", @active_locale == locale && "active"]}
              phx-click="switch_locale"
              phx-value-locale={locale}
              phx-target={@myself}
            >
              <%= locale_name(locale) %>
              <span class={["status", translation_complete?(@product, locale) && "complete"]}>
                <%= if translation_complete?(@product, locale), do: "✓", else: "○" %>
              </span>
            </button>
          <% end %>
        </div>
        
        <%!-- Active locale form fields --%>
        <div class="locale-content" data-locale={@active_locale}>
          <.translation_field 
            form={@form} 
            field={:name} 
            locales={[@active_locale]}
            label="Product Name"
          />
          
          <.translation_field 
            form={@form} 
            field={:description} 
            locales={[@active_locale]}
            type="textarea"
            label="Product Description"
          />
        </div>
        
        <%!-- Live preview --%>
        <div class="live-preview">
          <h4>Preview</h4>
          <div class="preview-card">
            <h5><%= get_translation_preview(@form, :name, @active_locale) %></h5>
            <p><%= get_translation_preview(@form, :description, @active_locale) %></p>
          </div>
        </div>
        
        <%!-- Overall progress --%>
        <.translation_progress resource={@product} locales={@locales} />
        
        <div class="actions">
          <.button type="submit" disabled={not @form.valid?}>
            Save Translations
          </.button>
          
          <button 
            type="button"
            class="btn btn-secondary"
            phx-click="auto_translate"
            phx-target={@myself}
          >
            Auto-translate missing
          </button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket = 
      socket
      |> assign(assigns)
      |> assign_new(:active_locale, fn -> List.first(assigns.locales) end)
    
    {:ok, socket}
  end

  @impl true
  def handle_event("switch_locale", %{"locale" => locale}, socket) do
    {:noreply, assign(socket, :active_locale, String.to_atom(locale))}
  end

  @impl true
  def handle_event("validate", %{"product" => params}, socket) do
    form = validate_translations(socket.assigns.product, params)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"product" => params}, socket) do
    case save_translations(socket.assigns.product, params) do
      {:ok, product} ->
        # Broadcast update to other connected clients
        broadcast_translation_changes(product, params)
        
        send(self(), {:translation_saved, product})
        {:noreply, socket}
      
      {:error, changeset} ->
        form = to_form(changeset)
        {:noreply, assign(socket, :form, form)}
    end
  end

  @impl true
  def handle_event("auto_translate", _params, socket) do
    # Implement auto-translation logic
    # This could integrate with translation services
    {:noreply, put_flash(socket, :info, "Auto-translation started...")}
  end
  
  # Private helpers
  
  defp translation_complete?(product, locale) do
    # Check if all required fields are translated for this locale
    required_fields = [:name]  # Define your required fields
    
    Enum.all?(required_fields, fn field ->
      case translate_field(product, field, locale) do
        nil -> false
        "" -> false
        _value -> true
      end
    end)
  end
  
  defp get_translation_preview(form, field, locale) do
    storage_field = :"#{field}_translations"
    
    case Phoenix.HTML.Form.input_value(form, storage_field) do
      %{} = translations -> 
        Map.get(translations, locale) || Map.get(translations, to_string(locale)) || ""
      _ -> 
        ""
    end
  end
end
```

## CSS and Styling

### Basic CSS for Translation Components

```css
/* Translation status badges */
.translation-status {
  display: flex;
  gap: 0.25rem;
  flex-wrap: wrap;
}

.translation-status .badge {
  padding: 0.125rem 0.375rem;
  border-radius: 0.25rem;
  font-size: 0.75rem;
  font-weight: 600;
}

.translation-status .badge-complete {
  background-color: #10b981;
  color: white;
}

.translation-status .badge-missing {
  background-color: #f59e0b;
  color: white;
}

/* Language switcher */
.language-switcher {
  display: flex;
  list-style: none;
  margin: 0;
  padding: 0;
  gap: 0.5rem;
}

.language-switcher li {
  margin: 0;
}

.language-switcher a {
  padding: 0.5rem 1rem;
  border: 1px solid #d1d5db;
  border-radius: 0.375rem;
  text-decoration: none;
  color: #374151;
  transition: all 0.2s;
}

.language-switcher .active a {
  background-color: #3b82f6;
  color: white;
  border-color: #3b82f6;
}

.language-switcher a:hover {
  background-color: #f3f4f6;
}

/* Translation forms */
.translation-fields {
  display: grid;
  gap: 1rem;
}

.translation-field {
  padding: 1rem;
  border: 1px solid #d1d5db;
  border-radius: 0.5rem;
}

.translation-field[data-locale="en"] {
  border-color: #3b82f6;
  background-color: #eff6ff;
}

.translation-field label {
  display: block;
  font-weight: 600;
  margin-bottom: 0.5rem;
}

/* Translation progress */
.translation-progress {
  margin: 1rem 0;
}

.progress-bar {
  width: 100%;
  height: 1rem;
  background-color: #e5e7eb;
  border-radius: 0.5rem;
  overflow: hidden;
}

.progress-bar .progress {
  height: 100%;
  background-color: #10b981;
  transition: width 0.3s ease;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.75rem;
  font-weight: 600;
  color: white;
}

/* Locale tabs for LiveView */
.locale-tabs {
  display: flex;
  border-bottom: 1px solid #d1d5db;
  margin-bottom: 1rem;
}

.locale-tabs .tab {
  padding: 0.75rem 1rem;
  border: none;
  background: none;
  color: #6b7280;
  cursor: pointer;
  border-bottom: 2px solid transparent;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.locale-tabs .tab.active {
  color: #3b82f6;
  border-bottom-color: #3b82f6;
}

.locale-tabs .tab .status.complete {
  color: #10b981;
}

/* Responsive design */
@media (max-width: 768px) {
  .translation-fields {
    grid-template-columns: 1fr;
  }
  
  .language-switcher {
    flex-wrap: wrap;
  }
  
  .locale-tabs {
    flex-wrap: wrap;
  }
}
```

## JavaScript Integration

### Client-side Translation Helpers

```javascript
// assets/js/translation-helpers.js

export class TranslationHelpers {
  constructor() {
    this.initCharacterCounters();
    this.initAutoSave();
    this.initLocaleDetection();
  }
  
  // Character counting for translation fields
  initCharacterCounters() {
    const inputs = document.querySelectorAll('[data-translation-field]');
    
    inputs.forEach(input => {
      const counter = input.parentElement.querySelector('.char-count');
      if (!counter) return;
      
      const updateCount = () => {
        const count = input.value.length;
        const maxLength = input.getAttribute('maxlength');
        
        counter.textContent = maxLength 
          ? `${count}/${maxLength} characters`
          : `${count} characters`;
          
        if (maxLength && count > maxLength * 0.9) {
          counter.classList.add('warning');
        } else {
          counter.classList.remove('warning');
        }
      };
      
      input.addEventListener('input', updateCount);
      updateCount();
    });
  }
  
  // Auto-save translation drafts
  initAutoSave() {
    const forms = document.querySelectorAll('[data-translation-form]');
    
    forms.forEach(form => {
      const inputs = form.querySelectorAll('input, textarea');
      let saveTimeout;
      
      inputs.forEach(input => {
        input.addEventListener('input', () => {
          clearTimeout(saveTimeout);
          saveTimeout = setTimeout(() => {
            this.saveTranslationDraft(form);
          }, 2000); // Save after 2 seconds of inactivity
        });
      });
    });
  }
  
  saveTranslationDraft(form) {
    const formData = new FormData(form);
    const data = Object.fromEntries(formData.entries());
    const key = `translation_draft_${form.dataset.resourceId}`;
    
    localStorage.setItem(key, JSON.stringify({
      data: data,
      timestamp: Date.now()
    }));
    
    // Show save indicator
    const indicator = document.createElement('div');
    indicator.className = 'save-indicator';
    indicator.textContent = 'Draft saved';
    document.body.appendChild(indicator);
    
    setTimeout(() => {
      indicator.remove();
    }, 2000);
  }
  
  // Browser locale detection
  initLocaleDetection() {
    const detectedLocale = this.detectBrowserLocale();
    const currentLocale = document.documentElement.lang;
    
    if (detectedLocale !== currentLocale) {
      this.showLocaleRecommendation(detectedLocale);
    }
  }
  
  detectBrowserLocale() {
    const languages = navigator.languages || [navigator.language];
    const supportedLocales = ['en', 'es', 'fr', 'de']; // Configure as needed
    
    for (const lang of languages) {
      const locale = lang.split('-')[0];
      if (supportedLocales.includes(locale)) {
        return locale;
      }
    }
    
    return 'en'; // fallback
  }
  
  showLocaleRecommendation(recommendedLocale) {
    const banner = document.createElement('div');
    banner.className = 'locale-recommendation';
    banner.innerHTML = `
      <p>It looks like you prefer ${this.getLocaleName(recommendedLocale)}. 
         <a href="?locale=${recommendedLocale}">Switch to ${this.getLocaleName(recommendedLocale)}</a>
      </p>
      <button onclick="this.parentElement.remove()">×</button>
    `;
    
    document.body.insertBefore(banner, document.body.firstChild);
  }
  
  getLocaleName(locale) {
    const names = {
      en: 'English',
      es: 'Español',
      fr: 'Français',
      de: 'Deutsch'
    };
    return names[locale] || locale;
  }
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  new TranslationHelpers();
});
```

This comprehensive Phoenix integration guide covers all the essential aspects of using AshPhoenixTranslations in Phoenix applications, from basic setup to advanced LiveView patterns.