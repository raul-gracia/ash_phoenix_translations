defmodule AshPhoenixTranslations.Helpers do
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
  """

  alias Phoenix.HTML
  alias Phoenix.HTML.Form
  import Phoenix.HTML.Tag

  @doc """
  Translates a field from a resource.
  
  ## Examples
  
      <%= t(@product, :name) %>
      <%= t(@product, :description, locale: "es") %>
      <%= t(@product, :name, fallback: "Untitled") %>
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
  Translates a field from a resource with HTML safety.
  
  Useful for fields that contain HTML or markdown.
  
      <%= raw_t(@product, :description) %>
  """
  def raw_t(resource, field, opts \\ []) do
    t(resource, field, opts)
    |> HTML.raw()
  end

  @doc """
  Gets a specific translation field value.
  
      <%= translate_field(@product, :name, "es") %>
  """
  def translate_field(resource, field, locale) when is_binary(locale) do
    translate_field(resource, field, String.to_atom(locale))
  end

  def translate_field(resource, field, locale) when is_atom(locale) do
    storage_field = :"#{field}_translations"
    
    case Map.get(resource, storage_field) do
      nil -> nil
      translations when is_map(translations) ->
        Map.get(translations, locale) || Map.get(translations, to_string(locale))
      _ -> nil
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
    options = build_locale_options(opts[:options] || default_locales())
    selected = opts[:selected] || Form.input_value(form, field)
    
    Form.select(form, field, options, 
      selected: selected,
      class: opts[:class],
      id: opts[:id]
    )
  end

  @doc """
  Generates translation input fields for a form.
  
      <%= translation_inputs f, :name do %>
        <%= for locale <- [:en, :es, :fr] do %>
          <div>
            <%= label f, "#{:name}_#{locale}", locale_name(locale) %>
            <%= text_input f, "#{:name}_#{locale}" %>
          </div>
        <% end %>
      <% end %>
  """
  defmacro translation_inputs(form, field, locales \\ nil, do: block) do
    quote do
      locales = unquote(locales) || [:en, :es, :fr]
      
      content_tag :div, class: "translation-inputs" do
        for locale <- locales do
          var!(locale) = locale
          var!(field_name) = :"#{unquote(field)}_#{locale}"
          var!(form) = unquote(form)
          
          unquote(block)
        end
      end
    end
  end

  @doc """
  Generates a simple translation field input.
  
      <%= translation_input f, :name, :es %>
  """
  def translation_input(form, field, locale, opts \\ []) do
    field_name = :"#{field}_translations.#{locale}"
    label_text = opts[:label] || "#{humanize(field)} (#{locale_name(locale)})"
    
    content_tag :div, class: "field" do
      [
        content_tag(:label, label_text, for: field_name),
        Form.text_input(form, field_name, 
          class: opts[:class],
          placeholder: opts[:placeholder],
          value: get_translation_value(form, field, locale)
        )
      ]
    end
  end

  @doc """
  Shows translation status badges.
  
      <%= translation_status(@product, :description) %>
      # Shows badges like: [EN ✓] [ES ✓] [FR ✗]
  """
  def translation_status(resource, field, opts \\ []) do
    translations = all_translations(resource, field)
    locales = opts[:locales] || Map.keys(translations) || [:en, :es, :fr]
    
    content_tag :div, class: "translation-status" do
      Enum.map(locales, fn locale ->
        translated = Map.get(translations, locale)
        status = if translated && translated != "", do: "complete", else: "missing"
        icon = if status == "complete", do: "✓", else: "✗"
        
        content_tag :span, class: "badge badge-#{status}" do
          "#{String.upcase(to_string(locale))} #{icon}"
        end
      end)
    end
  end

  @doc """
  Generates a language switcher component.
  
      <%= language_switcher(@conn, @product.__struct__) %>
  """
  def language_switcher(conn, resource_module, opts \\ []) do
    current = current_locale(conn)
    locales = AshPhoenixTranslations.Info.supported_locales(resource_module)
    
    content_tag :ul, class: opts[:class] || "language-switcher" do
      Enum.map(locales, fn locale ->
        locale_str = to_string(locale)
        active = locale_str == current
        
        content_tag :li, class: if(active, do: "active", else: "") do
          content_tag :a, 
            href: locale_url(conn, locale_str),
            "data-locale": locale_str do
            locale_name(locale)
          end
        end
      end)
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
  
      <%= translation_completeness(@product) %>
      # => 66.7 (if 2 out of 3 locales are translated)
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
    
    case Form.input_value(form, storage_field) do
      nil -> nil
      translations when is_map(translations) ->
        Map.get(translations, locale) || Map.get(translations, to_string(locale))
      _ -> nil
    end
  end

  defp translatable_fields(resource) do
    resource.__struct__
    |> AshPhoenixTranslations.Info.translatable_attributes()
    |> Enum.map(& &1.name)
  end
end