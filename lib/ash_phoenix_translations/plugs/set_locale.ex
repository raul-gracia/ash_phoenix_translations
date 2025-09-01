defmodule AshPhoenixTranslations.Plugs.SetLocale do
  @moduledoc """
  Plug for setting the locale in the connection.

  This plug detects and sets the locale for the current request.

  ## Usage

  Add to your router pipeline:

      pipeline :browser do
        # ... other plugs
        plug AshPhoenixTranslations.Plugs.SetLocale,
          strategies: [:param, :session, :header],
          fallback: "en"
      end

  Or use with default settings:

      plug AshPhoenixTranslations.Plugs.SetLocale

  ## Options

    * `:strategies` - List of strategies to try in order. Default: `[:auto]`
      Available strategies:
      - `:param` - From URL parameter (?locale=en)
      - `:session` - From session
      - `:cookie` - From cookie
      - `:header` - From Accept-Language header
      - `:subdomain` - From subdomain (en.example.com)
      - `:path` - From URL path (/en/products)
      - `:user` - From authenticated user preference
      - `:auto` - Tries multiple strategies automatically
    
    * `:fallback` - Default locale if none found. Default: `"en"`
    
    * `:supported` - List of supported locales. Default: all locales accepted
    
    * `:persist` - Where to persist the locale. Can be `:session`, `:cookie`, 
      or a list like `[:session, :cookie]`. Default: `[:session]`
    
    * `:param_key` - The query parameter name. Default: `"locale"`
    
    * `:session_key` - The session key name. Default: `:locale`
    
    * `:cookie_key` - The cookie name. Default: `"locale"`
    
    * `:cookie_options` - Options for the locale cookie. Default: `[max_age: 365 * 24 * 60 * 60]`
  """

  import Plug.Conn
  alias AshPhoenixTranslations.LocaleResolver

  @default_strategies [:auto]
  @default_fallback "en"
  @default_persist [:session]

  def init(opts) do
    %{
      strategies: Keyword.get(opts, :strategies, @default_strategies),
      fallback: Keyword.get(opts, :fallback, @default_fallback),
      supported: Keyword.get(opts, :supported),
      persist: List.wrap(Keyword.get(opts, :persist, @default_persist)),
      param_key: Keyword.get(opts, :param_key, "locale"),
      session_key: Keyword.get(opts, :session_key, :locale),
      cookie_key: Keyword.get(opts, :cookie_key, "locale"),
      cookie_options: Keyword.get(opts, :cookie_options, max_age: 365 * 24 * 60 * 60),
      custom_resolver: Keyword.get(opts, :custom_resolver)
    }
  end

  def call(conn, config) do
    locale = resolve_locale(conn, config)

    conn
    |> set_locale(locale, config)
    |> persist_locale(locale, config)
    |> maybe_redirect_with_locale(locale, config)
  end

  # Resolve locale using configured strategies
  defp resolve_locale(conn, config) do
    resolver_config = %{
      strategies: config.strategies,
      fallback: config.fallback,
      supported: config.supported,
      custom: config.custom_resolver
    }

    LocaleResolver.resolve_with_config(conn, resolver_config)
  end

  # Set locale in connection assigns and Gettext if available
  defp set_locale(conn, locale, _config) do
    conn =
      conn
      |> assign(:locale, locale)
      |> assign(:raw_locale, locale)

    # Set Gettext locale if Gettext is available
    if Code.ensure_loaded?(Gettext) &&
         function_exported?(conn.private[:phoenix_endpoint], :config, 1) do
      gettext_module = conn.private[:phoenix_endpoint].config(:gettext)

      if gettext_module && Code.ensure_loaded?(gettext_module) do
        Gettext.put_locale(gettext_module, locale)
      end
    end

    conn
  end

  # Persist locale to configured storage
  defp persist_locale(conn, locale, config) do
    Enum.reduce(config.persist, conn, fn storage, conn ->
      persist_to_storage(conn, locale, storage, config)
    end)
  end

  defp persist_to_storage(conn, locale, :session, config) do
    put_session(conn, config.session_key, locale)
  end

  defp persist_to_storage(conn, locale, :cookie, config) do
    put_resp_cookie(conn, config.cookie_key, locale, config.cookie_options)
  end

  defp persist_to_storage(conn, _locale, _storage, _config), do: conn

  # Optional: Redirect to URL with locale if configured
  defp maybe_redirect_with_locale(conn, _locale, _config) do
    # This could be implemented to redirect from /products to /en/products
    # if path-based locale strategy is used
    conn
  end
end
