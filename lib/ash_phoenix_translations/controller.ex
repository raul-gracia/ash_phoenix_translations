defmodule AshPhoenixTranslations.Controller do
  @moduledoc """
  Controller helpers for AshPhoenixTranslations.

  Import this module in your controllers to get translation helpers:

      defmodule MyAppWeb.ProductController do
        use MyAppWeb, :controller
        import AshPhoenixTranslations.Controller
        
        def show(conn, %{"id" => id}) do
          product = MyApp.Catalog.get!(Product, id)
          product = with_locale(conn, product)
          render(conn, "show.html", product: product)
        end
      end
  """

  import Plug.Conn
  alias AshPhoenixTranslations.LocaleResolver

  @doc """
  Sets the locale in the connection.

  Can be used as a plug or called directly:

      # As a plug in router
      plug :set_locale
      
      # Or with options
      plug :set_locale, resolver: :header
      
      # Or called directly
      conn = set_locale(conn, "es")
  """
  def set_locale(conn, opts \\ [])

  def set_locale(conn, locale) when is_binary(locale) or is_atom(locale) do
    locale = to_string(locale)

    conn
    |> put_session(:locale, locale)
    |> assign(:locale, locale)
  end

  def set_locale(conn, opts) when is_list(opts) do
    resolver = Keyword.get(opts, :resolver, :auto)
    fallback = Keyword.get(opts, :fallback, "en")

    locale = LocaleResolver.resolve(conn, resolver) || fallback

    conn
    |> put_session(:locale, locale)
    |> assign(:locale, locale)
  end

  @doc """
  Translates a resource or list of resources based on the connection's locale.

      product = with_locale(conn, product)
      products = with_locale(conn, products)
  """
  def with_locale(conn, resource_or_resources) do
    locale = get_locale(conn)
    AshPhoenixTranslations.translate(resource_or_resources, locale)
  end

  @doc """
  Gets the current locale from the connection.

      locale = get_locale(conn)
  """
  def get_locale(conn) do
    conn.assigns[:locale] ||
      get_session(conn, :locale) ||
      LocaleResolver.resolve(conn, :auto) ||
      "en"
  end

  @doc """
  Temporarily switches locale for a block of code.

      with_locale conn, "es" do
        # Code here runs with Spanish locale
        product = Ash.get!(Product, id)
      end
  """
  defmacro with_locale(conn, locale, do: block) do
    quote do
      original_locale = unquote(__MODULE__).get_locale(unquote(conn))

      try do
        conn = unquote(__MODULE__).set_locale(unquote(conn), unquote(locale))
        var!(conn) = conn
        unquote(block)
      after
        unquote(__MODULE__).set_locale(var!(conn), original_locale)
      end
    end
  end

  @doc """
  Returns available locales for a resource.

      locales = available_locales(Product)
      # => [:en, :es, :fr]
  """
  def available_locales(resource) do
    AshPhoenixTranslations.Info.supported_locales(resource)
  end

  @doc """
  Checks if a locale is supported for a resource.

      if locale_supported?(Product, "es") do
        # Spanish is supported
      end
  """
  def locale_supported?(resource, locale) do
    locale = to_atom(locale)
    locale in available_locales(resource)
  end

  @doc """
  Gets translation errors from a changeset.

      case Ash.create(Product, params) do
        {:error, changeset} ->
          errors = translation_errors(changeset)
          # => [name: "Spanish translation is required"]
      end
  """
  def translation_errors(changeset) do
    changeset.errors
    |> Enum.filter(fn error ->
      String.contains?(to_string(error.field), "_translations") ||
        String.contains?(error.message || "", "translation")
    end)
    |> Enum.map(fn error ->
      field_string =
        error.field
        |> to_string()
        |> String.replace("_translations", "")

      field =
        try do
          String.to_existing_atom(field_string)
        rescue
          ArgumentError -> String.to_atom(field_string)
        end

      {field, error.message}
    end)
  end

  @doc """
  Builds a locale switcher data structure.

      switcher_data = locale_switcher(conn, Product)
      # => [
      #   %{code: "en", name: "English", active: true, url: "?locale=en"},
      #   %{code: "es", name: "Español", active: false, url: "?locale=es"}
      # ]
  """
  def locale_switcher(conn, resource) do
    current_locale = get_locale(conn)

    resource
    |> available_locales()
    |> Enum.map(fn locale ->
      %{
        code: to_string(locale),
        name: locale_name(locale),
        active: to_string(locale) == current_locale,
        url: build_locale_url(conn, locale)
      }
    end)
  end

  @doc """
  Sets translation context for Ash operations.

      conn
      |> set_translation_context()
      |> Ash.create!(Product, params)
  """
  def set_translation_context(conn) do
    locale = get_locale(conn)
    actor = conn.assigns[:current_user]

    %{
      locale: locale,
      actor: actor,
      private: %{
        ash_phoenix_translations: %{
          locale: locale,
          conn: conn
        }
      }
    }
  end

  # Private helpers

  defp to_atom(value) when is_atom(value), do: value

  defp to_atom(value) when is_binary(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError ->
      reraise ArgumentError,
              "Invalid locale atom: #{inspect(value)}. Only predefined locales are allowed.",
              __STACKTRACE__
  end

  defp locale_name(locale) do
    # This could be enhanced with a proper locale names mapping
    case locale do
      :en ->
        "English"

      :es ->
        "Español"

      :fr ->
        "Français"

      :de ->
        "Deutsch"

      :it ->
        "Italiano"

      :pt ->
        "Português"

      :ja ->
        "日本語"

      :zh ->
        "中文"

      :ko ->
        "한국어"

      :ar ->
        "العربية"

      :ru ->
        "Русский"

      other ->
        other
        |> to_string()
        |> String.upcase()
    end
  end

  defp build_locale_url(conn, locale) do
    query_params =
      conn.query_params
      |> Map.put("locale", to_string(locale))
      |> URI.encode_query()

    "#{conn.request_path}?#{query_params}"
  end
end
