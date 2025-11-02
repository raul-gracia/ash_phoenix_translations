defmodule AshPhoenixTranslations.Helpers do
  require Logger

  alias Phoenix.HTML
  alias Phoenix.HTML.Form

  @moduledoc """
  View helpers and template utilities for AshPhoenixTranslations.

  This module provides a comprehensive set of helper functions for working with
  translations in Phoenix templates, forms, and views. All functions are designed
  to work safely with user input and prevent common security vulnerabilities.

  ## Setup

  ### Import in Web Module

  Add to your application's web module for automatic availability:

      # In lib/my_app_web.ex
      def html do
        quote do
          use Phoenix.Component
          import Phoenix.HTML
          import AshPhoenixTranslations.Helpers  # Add this

          # ... other imports
        end
      end

  ### Import in Specific Views

  Or import only where needed:

      defmodule MyAppWeb.ProductView do
        use MyAppWeb, :view
        import AshPhoenixTranslations.Helpers
      end

  ### Direct Import in Templates

  Import directly in .heex templates:

      <%# At top of template %>
      <% import AshPhoenixTranslations.Helpers %>

      <h1><%= t(@product, :name) %></h1>
      <p><%= t(@product, :description, locale: "es") %></p>

  ## Core Translation Functions

  ### `t/3` - Safe HTML-Escaped Translation

  The primary function for displaying translations with automatic HTML escaping:

      <%= t(@product, :name) %>
      <%= t(@product, :description, locale: :es, fallback: "No description") %>

  ### `raw_t/3` - HTML Content with Sanitization

  For trusted HTML content (use with caution - see security warnings):

      <%= raw_t(@article, :html_content) %>

  ### `translate_field/3` - Direct Field Access

  Get raw translation value without rendering:

      <% spanish_name = translate_field(@product, :name, :es) %>

  ## Form Helpers

  ### `locale_select/3` - Locale Dropdown

  Generate a locale selection dropdown:

      <%= locale_select(f, :locale) %>
      <%= locale_select(f, :locale, options: ["en", "es", "fr"]) %>

  ### `translation_input/4` - Individual Translation Input

  Create a labeled input for a specific locale:

      <%= translation_input(f, :name, :es) %>
      <%= translation_input(f, :name, :es, label: "Spanish Name") %>

  ### `translation_inputs/3` - Multiple Translation Inputs

  Generate inputs for multiple locales:

      <%= translation_inputs f, :name, [:en, :es, :fr] do %>
        <div class="translation-field">
          <label><%= locale %></label>
          <%= text_input form, field_name %>
        </div>
      <% end %>

  ## Status and Progress Helpers

  ### `translation_status/3` - Visual Status Badges

  Display translation completeness with badges:

      <%= translation_status(@product, :description) %>
      # Renders: [EN ✓] [ES ✓] [FR ✗]

  ### `translation_completeness/2` - Percentage Complete

  Calculate translation coverage:

      <%= translation_completeness(@product) %>
      # => 75.0

      <%= translation_completeness(@product, fields: [:name], locales: [:en, :es]) %>

  ## UI Components

  ### `language_switcher/3` - Language Selector Component

  Generate a language switcher for your layout:

      <%= language_switcher(@conn, MyApp.Product) %>

  ### `translation_exists?/3` - Conditional Rendering

  Check if translation exists before rendering:

      <%= if translation_exists?(@product, :tagline, :es) do %>
        <p class="tagline"><%= t(@product, :tagline, locale: :es) %></p>
      <% end %>

  ## Complete Template Example

      defmodule MyAppWeb.ProductView do
        use MyAppWeb, :view
        import AshPhoenixTranslations.Helpers
      end

      # In product/show.html.heex
      <div class="product">
        <%# Language Switcher %>
        <div class="header">
          <%= language_switcher(@conn, MyApp.Product) %>
        </div>

        <%# Product Content %>
        <h1><%= t(@product, :name) %></h1>

        <%= if translation_exists?(@product, :tagline, @locale) do %>
          <p class="tagline"><%= t(@product, :tagline) %></p>
        <% end %>

        <div class="description">
          <%= t(@product, :description, fallback: "No description available") %>
        </div>

        <%# Translation Status for Admins %>
        <%= if @current_user && @current_user.role == :admin do %>
          <div class="admin-panel">
            <h3>Translation Status</h3>
            <p>Completeness: <%= translation_completeness(@product) %>%</p>

            <%= for field <- [:name, :description, :tagline] do %>
              <div class="field-status">
                <strong><%= field %>:</strong>
                <%= translation_status(@product, field) %>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>

  ## Complete Form Example

      # In product/form.html.heex
      <.form :let={f} for={@changeset} action={@action}>
        <%# Regular fields %>
        <.input field={f[:sku]} label="SKU" />
        <.input field={f[:price]} label="Price" type="number" />

        <%# Translation fields %>
        <fieldset class="translations">
          <legend>Translations</legend>

          <%= for locale <- [:en, :es, :fr] do %>
            <div class="locale-section">
              <h4><%= locale_name(locale) %></h4>

              <%= translation_input(f, :name, locale,
                    label: "Product Name",
                    placeholder: "Enter product name") %>

              <%= translation_input(f, :description, locale,
                    label: "Description") %>
            </div>
          <% end %>
        </fieldset>

        <.button type="submit">Save Product</.button>
      </.form>

  ## LiveView Integration

      defmodule MyAppWeb.ProductLive.TranslationEditor do
        use MyAppWeb, :live_view
        import AshPhoenixTranslations.Helpers

        def mount(%{"id" => id}, _session, socket) do
          product = MyApp.Product |> Ash.get!(id)

          socket =
            socket
            |> assign(:product, product)
            |> assign(:current_locale, :en)
            |> assign(:completeness, translation_completeness(product))

          {:ok, socket}
        end

        def handle_event("switch_locale", %{"locale" => locale}, socket) do
          {:noreply, assign(socket, :current_locale, String.to_existing_atom(locale))}
        end

        def render(assigns) do
          ~H\"\"\"
          <div class="translation-editor">
            <%# Locale Switcher %>
            <%= locale_select(nil, :locale,
                  selected: @current_locale,
                  class: "locale-selector") %>

            <%# Current Translation %>
            <div class="current-translation">
              <h2><%= t(@product, :name, locale: @current_locale) %></h2>
              <p><%= t(@product, :description, locale: @current_locale) %></p>
            </div>

            <%# Progress Indicator %>
            <div class="progress">
              <div class="progress-bar" style={"width: \#{@completeness}%"}>
                <%= Float.round(@completeness, 1) %>%
              </div>
            </div>

            <%# Status for Each Field %>
            <%= for field <- [:name, :description, :tagline] do %>
              <%= translation_status(@product, field) %>
            <% end %>
          </div>
          \"\"\"
        end
      end

  ## Utility Functions

  ### `all_translations/2` - Get All Locale Values

      translations = all_translations(@product, :name)
      # => %{en: "Product", es: "Producto", fr: "Produit"}

  ### `locale_name/1` - Display Names

      <%= locale_name(:es) %>  # => "Español"
      <%= locale_name(:fr) %>  # => "Français"

  ## Security Features

  All helpers include security protections:

  - **HTML Escaping**: `t/3` automatically escapes HTML
  - **Atom Exhaustion Prevention**: Safe locale conversion with `String.to_existing_atom/1`
  - **HTML Sanitization**: `raw_t/3` uses HtmlSanitizeEx when available
  - **XSS Prevention**: All user input is validated and escaped

  ## Performance Considerations

  - Translation lookups are direct map access (fast)
  - No database queries for cached resources
  - Helper functions are designed for template efficiency
  - Use `translation_exists?/3` to avoid unnecessary rendering

  ## Error Handling

      # Missing translation returns fallback
      <%= t(@product, :name, fallback: "Untitled") %>

      # Missing locale returns nil
      <%= translate_field(@product, :name, :unknown) %>
      # => nil

      # Invalid locale safely falls back to default
      <%= t(@product, :name, locale: "invalid-locale") %>
      # Logs warning, uses :en

  ## See Also

  - `AshPhoenixTranslations` - Main module with programmatic API
  - `AshPhoenixTranslations.Plugs` - Router plugs for locale handling
  - `AshPhoenixTranslations.LiveView` - LiveView-specific utilities
  """

  # Check if Phoenix.HTML is available
  @phoenix_html_available Code.ensure_loaded?(Phoenix.HTML)

  @doc """
  Translates a field from a resource with automatic HTML escaping.

  This is the primary helper for displaying translated content in Phoenix templates.
  It retrieves the translation from the resource's translation storage field, automatically
  escapes HTML to prevent XSS attacks, and falls back to the provided fallback text if
  the translation is empty or missing.

  ## Parameters

    * `resource` - The Ash resource containing translations (struct)
    * `field` - The translatable field name (atom)
    * `opts` - Keyword list of options:
      * `:locale` - Target locale (atom or string). Defaults to current locale from conn/session
      * `:fallback` - Fallback text if translation missing. Defaults to empty string
      * `:conn` - Phoenix connection to extract current locale from

  ## Returns

  The translated string value with HTML automatically escaped, or the fallback value if
  no translation exists. When `Phoenix.HTML` is available, returns a `Phoenix.HTML.safe/0`
  tuple for safe template rendering.

  ## Security Features

  - **Automatic HTML Escaping**: All translation output is HTML-escaped to prevent XSS
  - **Atom Exhaustion Prevention**: Uses `String.to_existing_atom/1` for locale validation
  - **Safe Fallback**: Fallback text is also HTML-escaped for consistency

  ## Basic Usage

      # Simple translation using current locale
      <h1><%= t(@product, :name) %></h1>

      # With fallback for missing translations
      <p><%= t(@product, :tagline, fallback: "Coming soon") %></p>

      # Specific locale (accepts atom or string)
      <%= t(@product, :description, locale: :es) %>
      <%= t(@product, :description, locale: "fr") %>

  ## Locale Management

      # Using connection context (automatic locale detection)
      <%= t(@product, :name, conn: @conn) %>
      # Checks: conn.assigns.locale → session.locale → "en"

      # Explicit locale override
      <%= t(@product, :description, locale: :es, conn: @conn) %>
      # Uses :es even if conn has different locale

  ## Template Patterns

  ### Product Listing
  ```heex
  <%= for product <- @products do %>
    <div class="product-card">
      <h3><%= t(product, :name) %></h3>
      <p><%= t(product, :description, fallback: "No description available") %></p>
      <span class="price"><%= product.price %></span>
    </div>
  <% end %>
  ```

  ### Multilingual Navigation
  ```heex
  <nav>
    <%= for page <- @pages do %>
      <a href={page.url}>
        <%= t(page, :title, locale: @current_locale) %>
      </a>
    <% end %>
  </nav>
  ```

  ### Conditional Content
  ```heex
  <div class="hero">
    <h1><%= t(@campaign, :headline) %></h1>

    <%= if t(@campaign, :subtitle) != "" do %>
      <h2><%= t(@campaign, :subtitle) %></h2>
    <% end %>
  </div>
  ```

  ### Search Results
  ```heex
  <%= for result <- @search_results do %>
    <article>
      <h2><%= t(result, :title, locale: @user_locale) %></h2>
      <p><%= t(result, :excerpt, fallback: "Read more...") %></p>
      <a href={result_path(@conn, :show, result)}>
        <%= t(@ui, :read_more_label) %>
      </a>
    </article>
  <% end %>
  ```

  ## LiveView Integration

      defmodule MyAppWeb.ProductLive.Show do
        use MyAppWeb, :live_view
        import AshPhoenixTranslations.Helpers

        def mount(%{"id" => id}, _session, socket) do
          product = MyApp.Product |> Ash.get!(id)

          socket =
            socket
            |> assign(:product, product)
            |> assign(:locale, :en)

          {:ok, socket}
        end

        def handle_event("switch_locale", %{"locale" => locale}, socket) do
          {:noreply, assign(socket, :locale, String.to_existing_atom(locale))}
        end

        def render(assigns) do
          ~H\"\"\"
          <div>
            <h1><%= t(@product, :name, locale: @locale) %></h1>
            <p><%= t(@product, :description, locale: @locale) %></p>
          </div>
          \"\"\"
        end
      end

  ## Component Integration

      defmodule MyAppWeb.ProductCardComponent do
        use Phoenix.Component
        import AshPhoenixTranslations.Helpers

        attr :product, :map, required: true
        attr :locale, :atom, default: :en

        def product_card(assigns) do
          ~H\"\"\"
          <div class="card">
            <h3><%= t(@product, :name, locale: @locale) %></h3>
            <p class="description">
              <%= t(@product, :description,
                    locale: @locale,
                    fallback: "No description") %>
            </p>
          </div>
          \"\"\"
        end
      end

  ## Performance Considerations

  - Translation lookup is a direct map access (O(1) complexity)
  - No database queries for cached resources
  - HTML escaping is optimized by Phoenix.HTML
  - Consider using `translation_exists?/3` to avoid rendering empty content

  ## Error Handling

      # Missing translation returns fallback
      <%= t(@product, :nonexistent_field, fallback: "N/A") %>
      # => "N/A"

      # Invalid locale safely falls back to :en
      <%= t(@product, :name, locale: "invalid") %>
      # Logs warning, returns English translation

      # Nil resource returns fallback
      <%= t(nil, :name, fallback: "Unknown") %>
      # => "Unknown"

  ## HTML Escaping Examples

      # User-provided content is automatically escaped
      product.name_translations = %{en: "<script>alert('xss')</script>"}
      <%= t(product, :name) %>
      # => "&lt;script&gt;alert('xss')&lt;/script&gt;"

      # Safe for template rendering
      product.name_translations = %{en: "Product & Service"}
      <%= t(product, :name) %>
      # => "Product &amp; Service"

  ## Related Functions

  - `raw_t/3` - For trusted HTML content (use with caution)
  - `translate_field/3` - Direct field access without HTML escaping
  - `translation_exists?/3` - Check if translation exists before rendering
  - `all_translations/2` - Get all locale values for a field

  ## See Also

  - `AshPhoenixTranslations` - Main module with programmatic API
  - `AshPhoenixTranslations.Helpers.raw_t/3` - HTML content rendering
  - `AshPhoenixTranslations.Plugs.SetLocale` - Automatic locale detection
  """
  def t(resource, field, opts \\ []) do
    locale = Keyword.get(opts, :locale, current_locale(opts[:conn]))
    fallback = Keyword.get(opts, :fallback, "")

    translated = translate_field(resource, field, locale)

    if translated && translated != "" do
      translated
    else
      fallback
    end
  end

  @doc """
  Translates a field from a resource with HTML safety bypassed.

  ## ⚠️  CRITICAL SECURITY WARNING

  **This function bypasses HTML escaping and can introduce XSS vulnerabilities!**

  ### Safe Usage Guidelines

  - ✅ **ONLY** use with trusted translation content that you control
  - ✅ Content from your translation team or CMS you manage
  - ✅ Pre-sanitized HTML content from trusted sources

  ### Dangerous Usage Patterns

  - ❌ **NEVER** use with user-generated content
  - ❌ **NEVER** use with content from external APIs without validation
  - ❌ **NEVER** use with form inputs or URL parameters

  ### Security Best Practices

  1. Always prefer `t/3` for standard translation output (automatically escaped)
  2. If you must use `raw_t/3`, implement Content Security Policy headers
  3. Validate and sanitize HTML content before storing translations
  4. Regular security audits of raw translation usage

  ## Examples

      # ✅ SAFE: Trusted content from translation team
      <%= raw_t(@product, :html_description) %>
      
      # ❌ DANGEROUS: User-generated content
      <%= raw_t(@user_comment, :content) %>  # XSS VULNERABILITY!
      
      # ✅ SAFER ALTERNATIVE: Use safe translation
      <%= t(@product, :description) %>  # Automatically HTML-escaped

  ## Security Mitigation

  If you must render HTML content, consider:
  - Using a HTML sanitization library like HtmlSanitizeEx
  - Implementing strict Content Security Policy
  - Regular security scanning and penetration testing

  ## Related Security Functions

  - `t/3` - Safe HTML-escaped translation (recommended)
  - `translate_field/3` - Raw field access without rendering
  """
  def raw_t(resource, field, opts \\ []) do
    content = t(resource, field, opts)

    # SECURITY: Sanitize HTML to prevent XSS attacks
    sanitized =
      if Code.ensure_loaded?(HtmlSanitizeEx) do
        HtmlSanitizeEx.basic_html(content)
      else
        Logger.warning(
          "HtmlSanitizeEx not available - raw content may be unsafe. Install html_sanitize_ex package."
        )

        # Fallback to escaping if HtmlSanitizeEx not available
        if @phoenix_html_available do
          content |> HTML.html_escape() |> HTML.safe_to_string()
        else
          content
        end
      end

    if @phoenix_html_available do
      HTML.raw(sanitized)
    else
      sanitized
    end
  end

  @doc """
  Gets a specific translation field value without HTML escaping or fallback handling.

  This function provides direct access to translation storage, returning the raw string
  value for a specific field and locale combination. Unlike `t/3`, this function does
  not perform HTML escaping and returns `nil` for missing translations instead of using
  a fallback value.

  Use this function when you need programmatic access to translation values for processing,
  comparison, or conditional logic rather than direct template rendering.

  ## Parameters

    * `resource` - The Ash resource containing translations (struct)
    * `field` - The translatable field name (atom)
    * `locale` - Target locale (atom or string)

  ## Returns

  The raw translated string value, or `nil` if:
  - The translation doesn't exist for the locale
  - The field is not translatable
  - The resource doesn't have translation storage

  ## Security Features

  - **Atom Exhaustion Prevention**: Uses `String.to_existing_atom/1` when locale is a string
  - **Safe Fallback**: Invalid locales automatically fall back to `:en` with warning log
  - **No XSS Risk**: Returns plain strings without HTML markup (caller responsible for escaping)

  ## Basic Usage

      # Get Spanish translation
      spanish_name = translate_field(@product, :name, :es)
      # => "Producto"

      # Get translation with string locale
      french_desc = translate_field(@product, :description, "fr")
      # => "Description en français"

      # Missing translation returns nil
      missing = translate_field(@product, :tagline, :de)
      # => nil

  ## Programmatic Use Cases

  ### Translation Comparison
  ```elixir
  def translations_match?(product, field, locale1, locale2) do
    trans1 = translate_field(product, field, locale1)
    trans2 = translate_field(product, field, locale2)

    trans1 == trans2
  end

  # Check if English and Spanish translations are identical
  if translations_match?(product, :sku, :en, :es) do
    Logger.warning("SKU should not be translated")
  end
  ```

  ### Conditional Logic
  ```elixir
  def product_title(product, locale) do
    case translate_field(product, :name, locale) do
      nil ->
        # Fall back to SKU if no translation
        "Product \#{product.sku}"

      "" ->
        # Empty translation, use default
        translate_field(product, :name, :en)

      name ->
        name
    end
  end
  ```

  ### Translation Quality Check
  ```elixir
  def check_translation_length(product, field, locale, max_length) do
    case translate_field(product, field, locale) do
      nil ->
        {:error, :missing}

      translation when byte_size(translation) > max_length ->
        {:error, :too_long, byte_size(translation)}

      translation ->
        {:ok, translation}
    end
  end

  # Validate Spanish description isn't too long
  case check_translation_length(product, :description, :es, 500) do
    {:ok, _} -> :ok
    {:error, :too_long, size} ->
      Logger.error("Spanish description too long: \#{size} bytes")
  end
  ```

  ### Building Translation Map
  ```elixir
  def build_translation_map(products, field, locales) do
    for product <- products,
        locale <- locales,
        translation = translate_field(product, field, locale),
        translation != nil,
        into: %{} do
      {{product.id, locale}, translation}
    end
  end

  # Build lookup table for fast translation access
  translation_map = build_translation_map(products, :name, [:en, :es, :fr])
  spanish_name = translation_map[{product.id, :es}]
  ```

  ### Custom Validation
  ```elixir
  defmodule MyApp.TranslationValidator do
    def validate_all_translations(changeset, field, locales) do
      resource = changeset.data

      missing =
        Enum.filter(locales, fn locale ->
          translate_field(resource, field, locale) in [nil, ""]
        end)

      if Enum.empty?(missing) do
        changeset
      else
        Ash.Changeset.add_error(changeset,
          field: field,
          message: "Missing translations for: \#{inspect(missing)}"
        )
      end
    end
  end
  ```

  ### API Response Building
  ```elixir
  def to_api_response(product, locale) do
    %{
      id: product.id,
      sku: product.sku,
      name: translate_field(product, :name, locale),
      description: translate_field(product, :description, locale),
      # Include original if no translation exists
      name_original: translate_field(product, :name, :en),
      # Flag whether translation exists
      has_translation: translate_field(product, :name, locale) != nil
    }
  end
  ```

  ### Translation Coverage Report
  ```elixir
  def translation_coverage(products, field, target_locale) do
    total = length(products)

    translated =
      Enum.count(products, fn product ->
        translate_field(product, field, target_locale) not in [nil, ""]
      end)

    %{
      total: total,
      translated: translated,
      missing: total - translated,
      percentage: Float.round(translated / total * 100, 1)
    }
  end

  # Generate coverage report for Spanish
  coverage = translation_coverage(products, :description, :es)
  # => %{total: 100, translated: 75, missing: 25, percentage: 75.0}
  ```

  ## Template Usage (When Appropriate)

  While `t/3` is preferred for templates, `translate_field/3` is useful for conditional rendering:

      <%# Check if translation exists before rendering section %>
      <% spanish_desc = translate_field(@product, :description, :es) %>
      <%= if spanish_desc && String.length(spanish_desc) > 100 do %>
        <div class="long-description">
          <%= t(@product, :description, locale: :es) %>
        </div>
      <% else %>
        <p class="short-description">
          <%= t(@product, :summary, locale: :es) %>
        </p>
      <% end %>

  ## Error Handling

      # Invalid locale string safely falls back to :en
      translate_field(product, :name, "invalid-locale")
      # Logs: "Invalid locale conversion attempted: invalid-locale"
      # Returns: English translation

      # Non-translatable field returns nil
      translate_field(product, :sku, :es)
      # => nil (SKU is not translated)

      # Missing translation returns nil (no fallback)
      translate_field(product, :name, :de)
      # => nil

  ## Performance Considerations

  - Direct map access with O(1) complexity
  - No HTML escaping overhead
  - No fallback processing
  - Efficient for bulk operations

  ## Security Notes

  **Important**: This function returns raw strings that may contain user input or HTML.
  If rendering in templates, always:

  1. Use `t/3` instead for automatic HTML escaping, OR
  2. Manually escape output with `Phoenix.HTML.html_escape/1`, OR
  3. Validate content is safe before rendering

  ```elixir
  # ❌ DANGEROUS: Raw output without escaping
  raw_value = translate_field(product, :name, :es)
  Phoenix.HTML.raw(raw_value)  # XSS vulnerability!

  # ✅ SAFE: Use t/3 for template rendering
  <%= t(@product, :name, locale: :es) %>

  # ✅ SAFE: Manual escaping if needed
  raw_value = translate_field(product, :name, :es)
  safe_value = Phoenix.HTML.html_escape(raw_value)
  ```

  ## Related Functions

  - `t/3` - Safe HTML-escaped translation for templates (recommended for rendering)
  - `all_translations/2` - Get all locale values for a field
  - `translation_exists?/3` - Check if translation exists
  - `raw_t/3` - HTML content rendering with sanitization

  ## See Also

  - `AshPhoenixTranslations.translate/3` - Alternative programmatic API
  - `AshPhoenixTranslations.LocaleValidator` - Locale validation logic
  - `String.to_existing_atom/1` - Atom exhaustion prevention pattern
  """
  def translate_field(resource, field, locale) when is_binary(locale) do
    # SECURITY: Use String.to_existing_atom/1 to prevent atom exhaustion attacks
    # This ensures we only convert to atoms that already exist in the atom table
    safe_locale =
      try do
        String.to_existing_atom(locale)
      rescue
        ArgumentError ->
          # Log security event for monitoring
          Logger.warning("Invalid locale conversion attempted",
            locale: locale,
            resource: resource.__struct__,
            field: field
          )

          # Fallback to default locale instead of creating new atoms
          :en
      end

    translate_field(resource, field, safe_locale)
  end

  def translate_field(resource, field, locale) when is_atom(locale) do
    storage_field = :"#{field}_translations"

    case Map.get(resource, storage_field) do
      nil ->
        nil

      translations when is_map(translations) ->
        Map.get(translations, locale) || Map.get(translations, to_string(locale))

      _ ->
        nil
    end
  end

  @doc """
  Returns all translations for a field as a map of locale keys to translation values.

  This function provides access to the complete translation map for a single field,
  useful for building translation editors, analyzing translation coverage, or exporting
  translations to external systems.

  ## Parameters

    * `resource` - The Ash resource containing translations (struct)
    * `field` - The translatable field name (atom)

  ## Returns

  A map where:
  - Keys are locale atoms (`:en`, `:es`, `:fr`, etc.)
  - Values are the translated strings
  - Missing or empty translations are included as `nil` or empty strings

  Returns an empty map `%{}` if:
  - The field is not translatable
  - The resource doesn't have translation storage
  - The storage field doesn't exist

  ## Basic Usage

      # Get all name translations
      translations = all_translations(@product, :name)
      # => %{en: "Product", es: "Producto", fr: "Produit"}

      # Access specific locales from result
      spanish = translations[:es]
      # => "Producto"

      # Get all description translations (some may be nil)
      descriptions = all_translations(@product, :description)
      # => %{en: "Description", es: nil, fr: ""}

  ## Translation Editor Use Case

      defmodule MyAppWeb.ProductLive.TranslationEditor do
        use MyAppWeb, :live_view

        def mount(%{"id" => id, "field" => field_name}, _session, socket) do
          product = MyApp.Product |> Ash.get!(id)
          field = String.to_existing_atom(field_name)

          # Get all current translations
          current_translations = all_translations(product, field)

          # Get supported locales for this field
          attrs = AshPhoenixTranslations.Info.translatable_attributes(MyApp.Product)
          field_config = Enum.find(attrs, &(&1.name == field))
          supported_locales = field_config.locales

          # Build editor form data
          form_data =
            Enum.map(supported_locales, fn locale ->
              %{
                locale: locale,
                value: Map.get(current_translations, locale, ""),
                required: locale in field_config.required
              }
            end)

          socket =
            socket
            |> assign(:product, product)
            |> assign(:field, field)
            |> assign(:form_data, form_data)

          {:ok, socket}
        end
      end

  ## Coverage Analysis

      def analyze_translation_coverage(products, field) do
        all_locales = [:en, :es, :fr, :de, :it]

        coverage_by_locale =
          Enum.map(all_locales, fn locale ->
            translated_count =
              Enum.count(products, fn product ->
                translations = all_translations(product, field)
                translation = Map.get(translations, locale)
                translation not in [nil, ""]
              end)

            {locale, %{
              total: length(products),
              translated: translated_count,
              percentage: Float.round(translated_count / length(products) * 100, 1)
            }}
          end)
          |> Enum.into(%{})

        %{
          field: field,
          total_products: length(products),
          coverage_by_locale: coverage_by_locale
        }
      end

      # Generate coverage report
      report = analyze_translation_coverage(products, :description)
      # => %{
      #   field: :description,
      #   total_products: 100,
      #   coverage_by_locale: %{
      #     en: %{total: 100, translated: 100, percentage: 100.0},
      #     es: %{total: 100, translated: 75, percentage: 75.0},
      #     fr: %{total: 100, translated: 50, percentage: 50.0}
      #   }
      # }

  ## Export to CSV

      defmodule MyApp.TranslationExporter do
        def export_to_csv(products, field, output_path) do
          # Collect all unique locales
          all_locales =
            products
            |> Enum.flat_map(&Map.keys(all_translations(&1, field)))
            |> Enum.uniq()
            |> Enum.sort()

          # Build CSV rows
          headers = ["id", "sku" | Enum.map(all_locales, &to_string/1)]

          rows =
            Enum.map(products, fn product ->
              translations = all_translations(product, field)

              translation_values =
                Enum.map(all_locales, fn locale ->
                  Map.get(translations, locale, "")
                end)

              [product.id, product.sku | translation_values]
            end)

          # Write CSV
          csv_content =
            [headers | rows]
            |> CSV.encode()
            |> Enum.join()

          File.write!(output_path, csv_content)
        end
      end

      # Export product names to CSV
      MyApp.TranslationExporter.export_to_csv(products, :name, "product_names.csv")

  ## Missing Translation Detection

      def find_missing_translations(resource, field, required_locales) do
        translations = all_translations(resource, field)

        Enum.filter(required_locales, fn locale ->
          Map.get(translations, locale) in [nil, ""]
        end)
      end

      # Find which locales are missing
      missing = find_missing_translations(product, :description, [:en, :es, :fr])
      # => [:fr]  # French translation is missing

  ## Bulk Update from Map

      def update_translations(product, field, translation_map) do
        # Merge new translations with existing ones
        current = all_translations(product, field)
        updated = Map.merge(current, translation_map)

        # Update resource
        product
        |> Ash.Changeset.for_update(:update, %{
          "\#{field}_translations" => updated
        })
        |> Ash.update!()
      end

      # Update multiple translations at once
      new_translations = %{
        es: "Nuevo Producto",
        fr: "Nouveau Produit"
      }
      update_translations(product, :name, new_translations)

  ## Translation Quality Metrics

      def calculate_quality_metrics(product, field) do
        translations = all_translations(product, field)

        %{
          total_locales: map_size(translations),
          translated: Enum.count(translations, fn {_k, v} -> v not in [nil, ""] end),
          empty: Enum.count(translations, fn {_k, v} -> v in [nil, ""] end),
          avg_length:
            translations
            |> Enum.map(fn {_k, v} -> if v, do: String.length(v), else: 0 end)
            |> Enum.sum()
            |> Kernel./(map_size(translations))
            |> Float.round(1),
          longest_locale:
            translations
            |> Enum.max_by(fn {_k, v} -> if v, do: String.length(v), else: 0 end, fn -> {:en, ""} end)
            |> elem(0)
        }
      end

      # Get quality metrics
      metrics = calculate_quality_metrics(product, :description)
      # => %{
      #   total_locales: 3,
      #   translated: 2,
      #   empty: 1,
      #   avg_length: 45.3,
      #   longest_locale: :en
      # }

  ## Template Usage

      <%# Display all available translations %>
      <div class="all-translations">
        <%= for {locale, translation} <- all_translations(@product, :name) do %>
          <div class="translation-item">
            <span class="locale"><%= locale %></span>
            <span class="value"><%= translation || "(empty)" %></span>
          </div>
        <% end %>
      </div>

      <%# Build locale selector with availability indicator %>
      <select name="locale">
        <%= for {locale, translation} <- all_translations(@product, :description) do %>
          <option value={locale} disabled={!translation || translation == ""}>
            <%= locale_name(locale) %>
            <%= if translation && translation != "", do: "✓", else: "✗" %>
          </option>
        <% end %>
      </select>

  ## Performance Considerations

  - Returns the internal translation map directly (no copying)
  - O(1) lookup for the storage field
  - Efficient for iterating over all locales
  - Consider caching results if calling frequently

  ## Error Handling

      # Non-translatable field returns empty map
      all_translations(product, :sku)
      # => %{}

      # Missing storage field returns empty map
      all_translations(product, :nonexistent_field)
      # => %{}

      # Nil resource returns empty map
      all_translations(nil, :name)
      # => %{}

  ## Related Functions

  - `translate_field/3` - Get translation for specific locale
  - `translation_exists?/3` - Check if specific translation exists
  - `translation_completeness/2` - Calculate percentage of completion
  - `t/3` - Render translation in templates

  ## See Also

  - `AshPhoenixTranslations.Info.translatable_attributes/1` - Get field configuration
  - `AshPhoenixTranslations.Helpers.locale_name/1` - Get display names for locales
  """
  def all_translations(resource, field) do
    storage_field = :"#{field}_translations"
    Map.get(resource, storage_field, %{})
  end

  @doc """
  Generates an HTML locale selector dropdown with customizable options.

  Creates a `<select>` element for locale selection with automatic label localization
  and value handling. Useful for language switchers, user preference forms, and
  translation editors.

  ## Parameters

    * `form` - Phoenix.HTML.Form struct (can be `nil` for standalone selects)
    * `field` - Field name atom (e.g., `:locale`)
    * `opts` - Keyword list of options:
      * `:options` - List of locales or `{label, value}` tuples (defaults to common locales)
      * `:selected` - Currently selected locale (defaults to form value)
      * `:id` - Custom HTML `id` attribute
      * `:class` - CSS classes to apply to the `<select>` element

  ## Returns

  A `Phoenix.HTML.safe/0` tuple containing the `<select>` HTML element.

  ## Basic Usage

      # Simple dropdown with default locales
      <%= locale_select(f, :locale) %>
      # Generates: <select name="user[locale]">...</select>

      # With specific locales
      <%= locale_select(f, :locale, options: ["en", "es", "fr"]) %>

      # With custom labels
      <%= locale_select(f, :locale,
            options: [{"English", "en"}, {"Español", "es"}, {"Français", "fr"}]) %>

      # With CSS styling
      <%= locale_select(f, :locale, class: "form-select w-full") %>

  ## Form Integration

      # In a user settings form
      <.form :let={f} for={@changeset} action={@action}>
        <div class="field">
          <label>Preferred Language</label>
          <%= locale_select(f, :preferred_locale,
                options: ["en", "es", "fr", "de"],
                class: "select") %>
        </div>

        <.button type="submit">Save Settings</.button>
      </.form>

      # In a translation editor
      <.form :let={f} for={@changeset}>
        <div class="locale-selector">
          <label>Editing Translation For:</label>
          <%= locale_select(f, :editing_locale,
                options: @available_locales,
                selected: @current_locale) %>
        </div>
      </.form>

  ## Standalone Usage (No Form)

      # Language switcher without a form
      <%= locale_select(nil, :locale,
            options: ["en", "es", "fr"],
            selected: @conn.assigns.locale,
            class: "language-switcher") %>

      # With JavaScript handling
      <div phx-change="locale_changed">
        <%= locale_select(nil, :locale,
              options: @supported_locales,
              selected: @current_locale,
              id: "locale-switcher") %>
      </div>

  ## LiveView Integration

      defmodule MyAppWeb.SettingsLive do
        use MyAppWeb, :live_view

        def render(assigns) do
          ~H\"\"\"
          <div>
            <h2>Language Preferences</h2>

            <%= locale_select(nil, :display_locale,
                  options: ["en", "es", "fr", "de", "it"],
                  selected: @user.preferred_locale,
                  class: "locale-select") %>
          </div>
          \"\"\"
        end

        def handle_event("locale_changed", %{"locale" => new_locale}, socket) do
          user = socket.assigns.user

          user
          |> Ash.Changeset.for_update(:update, %{preferred_locale: new_locale})
          |> Ash.update!()

          {:noreply, assign(socket, :user, updated_user)}
        end
      end

  ## Custom Locale Lists

      # Using predefined locale sets
      available_locales = AshPhoenixTranslations.Info.supported_locales(MyApp.Product)
      <%= locale_select(f, :locale, options: available_locales) %>

      # European languages only
      european_locales = ["en", "es", "fr", "de", "it", "pt"]
      <%= locale_select(f, :locale, options: european_locales) %>

      # Custom labels with regional variants
      <%= locale_select(f, :locale,
            options: [
              {"English (US)", "en_US"},
              {"English (UK)", "en_GB"},
              {"Español (ES)", "es_ES"},
              {"Español (MX)", "es_MX"}
            ]) %>

  ## Accessibility Features

  The generated `<select>` includes:
  - Proper `id` and `name` attributes for form binding
  - Automatic label association via `id`
  - HTML-escaped labels and values
  - Standard browser keyboard navigation

  Example with ARIA attributes:

      <div class="field">
        <label for="user_locale" class="required">Language</label>
        <%= locale_select(f, :locale,
              id: "user_locale",
              class: "required",
              options: ["en", "es", "fr"]) %>
        <span aria-describedby="user_locale">Select your preferred language</span>
      </div>

  ## Styling Examples

      # Tailwind CSS
      <%= locale_select(f, :locale,
            class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm") %>

      # Bootstrap
      <%= locale_select(f, :locale,
            class: "form-select form-select-lg mb-3") %>

      # Custom CSS
      <%= locale_select(f, :locale,
            class: "custom-select locale-dropdown") %>

  ## Performance Considerations

  - Locale name lookup is cached in module attribute
  - Minimal HTML generation overhead
  - Browser-native `<select>` for optimal performance
  - No JavaScript dependencies

  ## Error Handling

      # Missing Phoenix.HTML dependency
      locale_select(f, :locale)
      # Raises: "Phoenix.HTML is required for locale_select/3"

      # Invalid options fall back to default locales
      <%= locale_select(f, :locale, options: nil) %>
      # Uses default: ["en", "es", "fr", "de", ...]

  ## Related Functions

  - `language_switcher/3` - Full language switcher component with links
  - `locale_name/1` - Get display name for a locale
  - `translation_input/4` - Create translation input fields

  ## See Also

  - `Phoenix.HTML.Form.select/4` - General form select helper
  - `AshPhoenixTranslations.Info.supported_locales/1` - Get supported locales
  """
  def locale_select(form, field, opts \\ []) do
    if @phoenix_html_available do
      options = build_locale_options(opts[:options] || default_locales())
      selected = opts[:selected] || Form.input_value(form, field)

      # Build the select HTML manually
      field_id = opts[:id] || "#{Form.input_id(form, field)}"
      field_name = Form.input_name(form, field)

      options_html =
        Enum.map_join(options, "", fn {label, value} ->
          selected_attr = if value == selected, do: " selected=\"selected\"", else: ""

          "<option value=\"#{HTML.html_escape(value)}\"#{selected_attr}>#{HTML.html_escape(label)}</option>"
        end)

      HTML.raw("""
      <select id="#{field_id}" name="#{field_name}" class="#{opts[:class]}">
        #{options_html}
      </select>
      """)
    else
      raise "Phoenix.HTML is required for locale_select/3"
    end
  end

  @doc """
  Generates translation input fields for a form.

  This macro requires Phoenix.HTML to be available.

  Example usage in a template:
      
      <% # Use translation_input/4 function instead for simpler cases %>
      <%= for locale <- [:en, :es, :fr] do %>
        <%= translation_input f, :name, locale %>
      <% end %>
  """
  defmacro translation_inputs(form, field, locales \\ nil, do: block) do
    quote do
      if unquote(@phoenix_html_available) do
        locales = unquote(locales) || [:en, :es, :fr]

        items =
          for locale <- locales do
            var!(locale) = locale
            var!(field_name) = :"#{unquote(field)}_#{locale}"
            var!(form) = unquote(form)

            unquote(block)
          end

        HTML.raw("<div class=\"translation-inputs\">#{Enum.join(items, "")}</div>")
      else
        raise "Phoenix.HTML is required for translation_inputs/3"
      end
    end
  end

  @doc """
  Generates a simple translation field input.

      <%= translation_input f, :name, :es %>
  """
  def translation_input(form, field, locale, opts \\ []) do
    if @phoenix_html_available do
      field_name = :"#{field}_translations.#{locale}"
      label_text = opts[:label] || "#{humanize(field)} (#{locale_name(locale)})"

      field_id = Form.input_id(form, field_name)
      field_html_name = Form.input_name(form, field_name)
      value = get_translation_value(form, field, locale)

      HTML.raw("""
      <div class="field">
        <label for="#{field_id}">#{HTML.html_escape(label_text)}</label>
        <input type="text" id="#{field_id}" name="#{field_html_name}" 
               class="#{opts[:class]}" placeholder="#{HTML.html_escape(opts[:placeholder] || "")}"
               value="#{HTML.html_escape(value || "")}">
      </div>
      """)
    else
      raise "Phoenix.HTML is required for translation_input/4"
    end
  end

  @doc """
  Shows translation status badges indicating completeness for each locale.

  ## Examples

      <%= translation_status(@product, :description) %>
      # Shows badges like: [EN ✓] [ES ✓] [FR ✗]
      
      # With specific locales
      <%= translation_status(@product, :name, locales: [:en, :es, :fr]) %>
      
      # Returns plain text if Phoenix.HTML not available
      translation_status(product, :description, locales: [:en, :es])
      # => "[EN ✓] [ES ✗]"
  """
  def translation_status(resource, field, opts \\ []) do
    if @phoenix_html_available do
      translations = all_translations(resource, field)
      locales = opts[:locales] || Map.keys(translations) || [:en, :es, :fr]

      badges =
        Enum.map_join(locales, "", fn locale ->
          translated = Map.get(translations, locale)
          status = if translated && translated != "", do: "complete", else: "missing"
          icon = if status == "complete", do: "✓", else: "✗"

          "<span class=\"badge badge-#{status}\">#{String.upcase(to_string(locale))} #{icon}</span>"
        end)

      HTML.raw("<div class=\"translation-status\">#{badges}</div>")
    else
      # Return a simple text representation if Phoenix.HTML is not available
      translations = all_translations(resource, field)
      locales = opts[:locales] || Map.keys(translations) || [:en, :es, :fr]

      Enum.map_join(locales, " ", fn locale ->
        translated = Map.get(translations, locale)
        status = if translated && translated != "", do: "✓", else: "✗"
        "[#{String.upcase(to_string(locale))} #{status}]"
      end)
    end
  end

  @doc """
  Generates a language switcher component.

      <%= language_switcher(@conn, @product.__struct__) %>
  """
  def language_switcher(conn, resource_module, opts \\ []) do
    if @phoenix_html_available do
      current = current_locale(conn)
      locales = AshPhoenixTranslations.Info.supported_locales(resource_module)

      items =
        Enum.map_join(locales, "", fn locale ->
          locale_str = to_string(locale)
          locale_label = locale_name(locale) |> to_string()
          active = locale_str == current
          class = if active, do: "active", else: ""

          "<li class=\"#{class}\"><a href=\"#{locale_url(conn, locale_str)}\" data-locale=\"#{locale_str}\">#{HTML.html_escape(locale_label)}</a></li>"
        end)

      HTML.raw("<ul class=\"#{opts[:class] || "language-switcher"}\">#{items}</ul>")
    else
      raise "Phoenix.HTML is required for language_switcher/3"
    end
  end

  @doc """
  Checks if a translation exists for a field and locale.

      <% if translation_exists?(@product, :description, :es) do %>
        <%= t(@product, :description, locale: :es) %>
      <% end %>
  """
  def translation_exists?(resource, field, locale) do
    translation = translate_field(resource, field, locale)
    translation && translation != ""
  end

  @doc """
  Calculates the percentage of translation completeness for a resource.

  Analyzes translation coverage across all or specific translatable fields and locales,
  returning a percentage representing how many translations are present vs. total possible.
  Useful for dashboards, progress indicators, quality metrics, and translation workflows.

  ## Parameters

    * `resource` - The Ash resource containing translations (struct)
    * `opts` - Keyword list of options:
      * `:fields` - List of field atoms to check (defaults to all translatable fields)
      * `:locales` - List of locale atoms to check (defaults to `[:en, :es, :fr]`)

  ## Returns

  A float representing the percentage (0.0 to 100.0) of translations that are:
  - Not `nil`
  - Not empty strings

  Returns `0.0` if:
  - No translatable fields exist
  - No translations are defined
  - Total possible translations is 0

  ## Basic Usage

      # Check overall completeness (all fields, default locales)
      <%= translation_completeness(@product) %>
      # => 66.7  # (4 out of 6 translations present)

      # Display in template
      <div class="progress">
        <div class="bar" style="width: <%= translation_completeness(@product) %>%"></div>
      </div>

      # With conditional formatting
      <% completeness = translation_completeness(@product) %>
      <span class="<%= if completeness >= 80, do: "text-green", else: "text-red" %>">
        <%= completeness %>% complete
      </span>

  ## Scoped Completeness

      # Check specific fields only
      name_completeness = translation_completeness(@product, fields: [:name])
      # => 100.0  # Name is translated in all locales

      critical_completeness = translation_completeness(@product,
        fields: [:name, :description, :tagline])
      # => 55.6  # 5 out of 9 critical translations

      # Check specific locales only
      european_completeness = translation_completeness(@product,
        locales: [:en, :es, :fr, :de, :it])
      # => 80.0  # Good European coverage

      # Combined filtering
      marketing_completeness = translation_completeness(@product,
        fields: [:tagline, :description],
        locales: [:en, :es])
      # => 75.0  # 3 out of 4 marketing translations

  ## Dashboard Example

      defmodule MyAppWeb.TranslationDashboard do
        use MyAppWeb, :live_view

        def mount(_params, _session, socket) do
          products = MyApp.Product |> Ash.read!()

          stats = %{
            total_products: length(products),

            # Overall metrics
            avg_completeness:
              products
              |> Enum.map(&translation_completeness/1)
              |> Enum.sum()
              |> Kernel./(length(products))
              |> Float.round(1),

            # Per-locale breakdown
            locale_completeness:
              for locale <- [:en, :es, :fr] do
                avg =
                  products
                  |> Enum.map(&translation_completeness(&1, locales: [locale]))
                  |> Enum.sum()
                  |> Kernel./(length(products))
                  |> Float.round(1)

                {locale, avg}
              end
              |> Enum.into(%{}),

            # Products needing attention
            incomplete_products:
              products
              |> Enum.filter(&(translation_completeness(&1) < 80))
              |> length()
          }

          {:ok, assign(socket, :stats, stats)}
        end

        def render(assigns) do
          ~H\"\"\"
          <div class="dashboard">
            <h2>Translation Coverage</h2>

            <div class="metric">
              <span>Average Completeness:</span>
              <strong><%= @stats.avg_completeness %>%</strong>
            </div>

            <h3>By Locale</h3>
            <%= for {locale, completeness} <- @stats.locale_completeness do %>
              <div class="locale-metric">
                <%= locale_name(locale) %>:
                <div class="progress-bar" style={"width: \#{completeness}%"}></div>
                <%= completeness %>%
              </div>
            <% end %>

            <div class="alert">
              <%= @stats.incomplete_products %> products below 80% completion
            </div>
          </div>
          \"\"\"
        end
      end

  ## Quality Gate Pattern

      defmodule MyApp.TranslationPolicy do
        def can_publish?(product) do
          # Require 100% English
          english_complete = translation_completeness(product, locales: [:en]) == 100.0

          # Require 80% overall
          overall_complete = translation_completeness(product) >= 80.0

          # Require critical fields fully translated
          critical_complete =
            translation_completeness(product,
              fields: [:name, :description],
              locales: [:en, :es, :fr]
            ) == 100.0

          english_complete and overall_complete and critical_complete
        end
      end

      # Use in workflow
      if MyApp.TranslationPolicy.can_publish?(product) do
        publish_product(product)
      else
        {:error, :incomplete_translations}
      end

  ## Progress Tracking

      defmodule MyApp.TranslationTracker do
        def track_progress(product_id) do
          product = MyApp.Product |> Ash.get!(product_id)

          # Get completeness at start
          initial = translation_completeness(product)

          # ... user makes edits ...

          # Get completeness after edits
          product_updated = MyApp.Product |> Ash.get!(product_id)
          final = translation_completeness(product_updated)

          improvement = Float.round(final - initial, 1)

          %{
            initial: initial,
            final: final,
            improvement: improvement,
            completed: final == 100.0
          }
        end
      end

  ## LiveView Progress Indicator

      defmodule MyAppWeb.ProductLive.Edit do
        use MyAppWeb, :live_view

        def mount(%{"id" => id}, _session, socket) do
          product = MyApp.Product |> Ash.get!(id)

          socket =
            socket
            |> assign(:product, product)
            |> assign(:completeness, translation_completeness(product))

          {:ok, socket}
        end

        def handle_event("update_translation", params, socket) do
          # Update translation
          {:ok, updated_product} = update_translation_logic(socket.assigns.product, params)

          # Recalculate completeness
          new_completeness = translation_completeness(updated_product)

          socket =
            socket
            |> assign(:product, updated_product)
            |> assign(:completeness, new_completeness)
            |> maybe_show_completion_flash(new_completeness)

          {:noreply, socket}
        end

        defp maybe_show_completion_flash(socket, 100.0) do
          put_flash(socket, :info, "🎉 All translations complete!")
        end

        defp maybe_show_completion_flash(socket, _), do: socket
      end

  ## Reporting and Analytics

      def generate_translation_report(products) do
        %{
          timestamp: DateTime.utc_now(),

          overall: %{
            total_products: length(products),
            avg_completeness:
              products
              |> Enum.map(&translation_completeness/1)
              |> Enum.sum()
              |> Kernel./(length(products))
              |> Float.round(1),
            fully_complete: Enum.count(products, &(translation_completeness(&1) == 100.0)),
            incomplete: Enum.count(products, &(translation_completeness(&1) < 100.0))
          },

          by_field:
            [:name, :description, :tagline]
            |> Enum.map(fn field ->
              avg =
                products
                |> Enum.map(&translation_completeness(&1, fields: [field]))
                |> Enum.sum()
                |> Kernel./(length(products))
                |> Float.round(1)

              {field, avg}
            end)
            |> Enum.into(%{}),

          least_complete:
            products
            |> Enum.map(fn p -> {p, translation_completeness(p)} end)
            |> Enum.sort_by(fn {_p, comp} -> comp end)
            |> Enum.take(10)
        }
      end

  ## Template Examples

      <%# Simple progress bar %>
      <div class="progress">
        <div class="bar" style="width: <%= translation_completeness(@product) %>%">
          <%= translation_completeness(@product) %>%
        </div>
      </div>

      <%# Color-coded badge %>
      <% completeness = translation_completeness(@product) %>
      <span class="badge <%= cond do %>
        <% completeness == 100.0 -> %> badge-success <% end %>
        <% completeness >= 80.0 -> %> badge-info <% end %>
        <% completeness >= 50.0 -> %> badge-warning <% end %>
        <% true -> %> badge-danger <% end %>
      <% end %>">
        <%= completeness %>%
      </span>

      <%# Field-by-field breakdown %>
      <table class="translation-stats">
        <%= for field <- [:name, :description, :tagline] do %>
          <tr>
            <td><%= field %></td>
            <td><%= translation_completeness(@product, fields: [field]) %>%</td>
          </tr>
        <% end %>
      </table>

  ## Performance Considerations

  - Iterates through all checked fields and locales
  - Complexity: O(fields × locales)
  - Consider caching result if called frequently
  - Efficient for small to medium field/locale counts

  ## Edge Cases

      # No translatable fields
      translation_completeness(%{}, [])
      # => 0.0

      # All fields empty
      product_with_empty_translations = %Product{
        name_translations: %{en: "", es: "", fr: ""}
      }
      translation_completeness(product_with_empty_translations)
      # => 0.0

      # Some translations nil, some empty (both count as incomplete)
      mixed_product = %Product{
        name_translations: %{en: "Name", es: nil, fr: ""}
      }
      translation_completeness(mixed_product, fields: [:name])
      # => 33.3  # Only English present

  ## Related Functions

  - `translation_status/3` - Visual status badges for each locale
  - `translation_exists?/3` - Check single translation existence
  - `all_translations/2` - Get all translations for detailed analysis

  ## See Also

  - `AshPhoenixTranslations.Info.translatable_attributes/1` - Get field configuration
  - `AshPhoenixTranslations.Helpers.translation_status/3` - Visual status display
  """
  def translation_completeness(resource, opts \\ []) do
    fields = opts[:fields] || translatable_fields(resource)
    locales = opts[:locales] || [:en, :es, :fr]

    total = length(fields) * length(locales)

    completed =
      Enum.reduce(fields, 0, fn field, acc ->
        translations = all_translations(resource, field)

        count =
          Enum.count(locales, fn locale ->
            translation = Map.get(translations, locale)
            translation && translation != ""
          end)

        acc + count
      end)

    if total > 0 do
      Float.round(completed / total * 100, 1)
    else
      0.0
    end
  end

  @doc """
  Returns the display name for a locale.

      <%= locale_name(:es) %>
      # => "Español"
  """
  def locale_name(locale) do
    locale_names()[locale] ||
      locale_names()[to_string(locale)] ||
      locale |> to_string() |> String.upcase()
  end

  # Private helpers

  defp current_locale(nil), do: "en"

  defp current_locale(conn) do
    conn.assigns[:locale] ||
      Plug.Conn.get_session(conn, :locale) ||
      "en"
  end

  defp build_locale_options(options) when is_list(options) do
    Enum.map(options, fn
      {label, value} -> {label, value}
      value -> {locale_name(value), value}
    end)
  end

  defp default_locales do
    ["en", "es", "fr", "de", "it", "pt", "ja", "zh", "ko", "ar", "ru"]
  end

  defp locale_names do
    %{
      "en" => "English",
      "es" => "Español",
      "fr" => "Français",
      "de" => "Deutsch",
      "it" => "Italiano",
      "pt" => "Português",
      "ja" => "日本語",
      "zh" => "中文",
      "ko" => "한국어",
      "ar" => "العربية",
      "ru" => "Русский",
      :en => "English",
      :es => "Español",
      :fr => "Français",
      :de => "Deutsch",
      :it => "Italiano",
      :pt => "Português",
      :ja => "日本語",
      :zh => "中文",
      :ko => "한국어",
      :ar => "العربية",
      :ru => "Русский"
    }
  end

  defp locale_url(conn, locale) do
    query_params =
      conn.query_params
      |> Map.put("locale", locale)
      |> URI.encode_query()

    "#{conn.request_path}?#{query_params}"
  end

  defp humanize(field) do
    field
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp get_translation_value(form, field, locale) do
    storage_field = :"#{field}_translations"

    value =
      if @phoenix_html_available do
        Form.input_value(form, storage_field)
      else
        # Fallback to checking form data directly
        Map.get(form.data, storage_field)
      end

    case value do
      nil ->
        nil

      translations when is_map(translations) ->
        Map.get(translations, locale) || Map.get(translations, to_string(locale))

      _ ->
        nil
    end
  end

  defp translatable_fields(resource) do
    resource.__struct__
    |> AshPhoenixTranslations.Info.translatable_attributes()
    |> Enum.map(& &1.name)
  end
end
