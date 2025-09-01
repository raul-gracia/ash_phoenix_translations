defmodule AshPhoenixTranslations.Helpers do
  require Logger

  alias Phoenix.HTML
  alias Phoenix.HTML.Form

  @moduledoc """
  View helpers for AshPhoenixTranslations.

  Import this module in your views or view_helpers:

      # In your_app_web.ex
      def view do
        quote do
          # ... other imports
          import AshPhoenixTranslations.Helpers
        end
      end
      
  Or import directly in templates:

      <h1><%= t(@product, :name) %></h1>
      <p><%= t(@product, :description, locale: "es") %></p>
      
  ## Examples

      iex> product = %{
      ...>   name_translations: %{en: "Product", es: "Producto", fr: "Produit"},
      ...>   description_translations: %{en: "Great product", es: "Gran producto"}
      ...> }
      iex> AshPhoenixTranslations.Helpers.translate_field(product, :name, :es)
      "Producto"
      
      iex> AshPhoenixTranslations.Helpers.all_translations(product, :name)
      %{en: "Product", es: "Producto", fr: "Produit"}
      
      iex> AshPhoenixTranslations.Helpers.translation_exists?(product, :description, :fr)
      false
      
      iex> AshPhoenixTranslations.Helpers.locale_name(:es)
      "Español"
  """

  # Check if Phoenix.HTML is available
  @phoenix_html_available Code.ensure_loaded?(Phoenix.HTML)

  @doc """
  Translates a field from a resource.

  This is the main helper for displaying translated content in templates.
  It retrieves the translation from the resource's translation storage field
  and falls back to the provided fallback if the translation is empty.

  ## Examples

      # Basic usage - uses current locale
      <%= t(@product, :name) %>
      
      # With specific locale
      <%= t(@product, :description, locale: "es") %>
      <%= t(@product, :description, locale: :es) %>
      
      # With fallback text
      <%= t(@product, :name, fallback: "Untitled") %>
      
      # With connection context (gets locale from conn)
      <%= t(@product, :description, conn: @conn) %>
      
      # Combined options
      <%= t(@product, :tagline, locale: "fr", fallback: "No tagline") %>
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

    if @phoenix_html_available do
      HTML.raw(content)
    else
      content
    end
  end

  @doc """
  Gets a specific translation field value.

  ## Security Notes

  When passing locale as a string, this function uses `String.to_existing_atom/1` 
  to prevent atom exhaustion attacks. Invalid locales are logged and fall back 
  to the default locale (:en).

  ## Examples

      <%= translate_field(@product, :name, "es") %>
      <%= translate_field(@product, :name, :es) %>

  ## Parameters

    * `resource` - The Ash resource containing translations
    * `field` - The field name to translate (atom)
    * `locale` - Target locale (atom or string)

  ## Returns

  The translated string value or `nil` if no translation exists.
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
  Returns all translations for a field.

      translations = all_translations(@product, :name)
      # => %{en: "Product", es: "Producto", fr: "Produit"}
  """
  def all_translations(resource, field) do
    storage_field = :"#{field}_translations"
    Map.get(resource, storage_field, %{})
  end

  @doc """
  Generates a locale selector dropdown.

      <%= locale_select(f, :locale) %>
      <%= locale_select(f, :locale, options: ["en", "es", "fr"]) %>
      <%= locale_select(f, :locale, 
            options: [{"English", "en"}, {"Español", "es"}]) %>
  """
  def locale_select(form, field, opts \\ []) do
    if @phoenix_html_available do
      options = build_locale_options(opts[:options] || default_locales())
      selected = opts[:selected] || Form.input_value(form, field)

      # Build the select HTML manually
      field_id = opts[:id] || "#{Form.input_id(form, field)}"
      field_name = Form.input_name(form, field)

      options_html =
        Enum.map(options, fn {label, value} ->
          selected_attr = if value == selected, do: " selected=\"selected\"", else: ""

          "<option value=\"#{HTML.html_escape(value)}\"#{selected_attr}>#{HTML.html_escape(label)}</option>"
        end)
        |> Enum.join("")

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
        Enum.map(locales, fn locale ->
          translated = Map.get(translations, locale)
          status = if translated && translated != "", do: "complete", else: "missing"
          icon = if status == "complete", do: "✓", else: "✗"

          "<span class=\"badge badge-#{status}\">#{String.upcase(to_string(locale))} #{icon}</span>"
        end)
        |> Enum.join("")

      HTML.raw("<div class=\"translation-status\">#{badges}</div>")
    else
      # Return a simple text representation if Phoenix.HTML is not available
      translations = all_translations(resource, field)
      locales = opts[:locales] || Map.keys(translations) || [:en, :es, :fr]

      Enum.map(locales, fn locale ->
        translated = Map.get(translations, locale)
        status = if translated && translated != "", do: "✓", else: "✗"
        "[#{String.upcase(to_string(locale))} #{status}]"
      end)
      |> Enum.join(" ")
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
        Enum.map(locales, fn locale ->
          locale_str = to_string(locale)
          active = locale_str == current
          class = if active, do: "active", else: ""

          "<li class=\"#{class}\"><a href=\"#{locale_url(conn, locale_str)}\" data-locale=\"#{locale_str}\">#{HTML.html_escape(locale_name(locale))}</a></li>"
        end)
        |> Enum.join("")

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
  Returns a percentage of translation completeness.

  ## Examples

      # Check completeness for all translatable fields
      <%= translation_completeness(@product) %>
      # => 66.7 (if 2 out of 3 locales are translated)
      
      # Check specific fields only
      completeness = translation_completeness(@product, fields: [:name, :description])
      
      # Check specific locales only
      completeness = translation_completeness(@product, locales: [:en, :es])
      
      # Check both specific fields and locales
      completeness = translation_completeness(@product, 
        fields: [:name], 
        locales: [:en, :es, :fr]
      )
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
      to_string(locale) |> String.upcase()
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
