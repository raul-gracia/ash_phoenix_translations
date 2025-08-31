defmodule AshPhoenixTranslations.LocaleResolver do
  @moduledoc """
  Strategies for resolving the current locale from various sources.
  
  Supports multiple resolution strategies:
  - `:header` - From Accept-Language header
  - `:param` - From URL parameter
  - `:session` - From session
  - `:cookie` - From cookie
  - `:subdomain` - From subdomain
  - `:path` - From URL path segment
  - `:user` - From authenticated user preference
  - `:auto` - Tries multiple strategies in order
  """

  import Plug.Conn

  @doc """
  Resolves the locale using the specified strategy.
  
      locale = LocaleResolver.resolve(conn, :header)
      locale = LocaleResolver.resolve(conn, :auto)
  """
  def resolve(conn, strategy \\ :auto)

  def resolve(conn, :auto) do
    # Try strategies in order of precedence
    resolve(conn, :param) ||
      resolve(conn, :path) ||
      resolve(conn, :subdomain) ||
      resolve(conn, :user) ||
      resolve(conn, :session) ||
      resolve(conn, :cookie) ||
      resolve(conn, :header)
  end

  def resolve(conn, :header) do
    conn
    |> get_req_header("accept-language")
    |> parse_accept_language()
    |> find_supported_locale()
  end

  def resolve(conn, :param) do
    conn.params["locale"] || conn.query_params["locale"]
  end

  def resolve(conn, :session) do
    get_session(conn, :locale)
  end

  def resolve(conn, :cookie) do
    conn.cookies["locale"]
  end

  def resolve(conn, :subdomain) do
    case String.split(conn.host, ".") do
      [locale | _rest] when byte_size(locale) == 2 ->
        locale
      _ ->
        nil
    end
  end

  def resolve(conn, :path) do
    case conn.path_info do
      [locale | _rest] when byte_size(locale) == 2 ->
        locale
      _ ->
        nil
    end
  end

  def resolve(conn, :user) do
    case conn.assigns[:current_user] do
      %{locale: locale} when not is_nil(locale) ->
        to_string(locale)
      %{preferred_locale: locale} when not is_nil(locale) ->
        to_string(locale)
      _ ->
        nil
    end
  end

  def resolve(conn, custom) when is_function(custom, 1) do
    custom.(conn)
  end

  def resolve(_conn, _strategy), do: nil

  @doc """
  Configures a resolver chain with fallbacks.
  
      config = LocaleResolver.configure(
        strategies: [:param, :user, :header],
        fallback: "en",
        supported: ["en", "es", "fr"]
      )
      
      locale = LocaleResolver.resolve_with_config(conn, config)
  """
  def configure(opts) do
    %{
      strategies: Keyword.get(opts, :strategies, [:auto]),
      fallback: Keyword.get(opts, :fallback, "en"),
      supported: Keyword.get(opts, :supported, nil),
      custom: Keyword.get(opts, :custom, nil)
    }
  end

  @doc """
  Resolves locale using a configuration map.
  """
  def resolve_with_config(conn, config) do
    strategies = config[:strategies] || [:auto]
    fallback = config[:fallback] || "en"
    
    locale = 
      Enum.find_value(strategies, fn strategy ->
        if strategy == :custom && config[:custom] do
          resolve(conn, config[:custom])
        else
          resolve(conn, strategy)
        end
      end)
    
    if locale && supported?(locale, config[:supported]) do
      locale
    else
      fallback
    end
  end

  @doc """
  Persists the locale to the specified storage.
  
      LocaleResolver.persist(conn, "es", :session)
      LocaleResolver.persist(conn, "es", [:session, :cookie])
  """
  def persist(conn, locale, storage) when is_list(storage) do
    Enum.reduce(storage, conn, fn store, conn ->
      persist(conn, locale, store)
    end)
  end

  def persist(conn, locale, :session) do
    put_session(conn, :locale, locale)
  end

  def persist(conn, locale, :cookie) do
    put_resp_cookie(conn, "locale", locale, max_age: 365 * 24 * 60 * 60)
  end

  def persist(conn, _locale, :user) do
    case conn.assigns[:current_user] do
      %{__struct__: _module} = _user ->
        # This would need to be implemented based on your user system
        # For example:
        # Ash.update!(user, %{locale: locale})
        conn
      _ ->
        conn
    end
  end

  def persist(conn, _locale, _storage), do: conn

  # Private helpers

  defp parse_accept_language([]), do: []
  defp parse_accept_language([header | _]) do
    header
    |> String.split(",")
    |> Enum.map(&parse_language_tag/1)
    |> Enum.sort_by(fn {_lang, quality} -> quality end, :desc)
    |> Enum.map(fn {lang, _quality} -> lang end)
  end
  defp parse_accept_language(_), do: []

  defp parse_language_tag(tag) do
    case String.split(tag, ";") do
      [lang] ->
        {String.trim(lang) |> String.split("-") |> List.first() |> String.downcase(), 1.0}
      [lang, quality] ->
        quality_value = 
          quality
          |> String.trim()
          |> String.replace("q=", "")
          |> Float.parse()
          |> case do
            {q, _} -> q
            :error -> 0.0
          end
        
        {String.trim(lang) |> String.split("-") |> List.first() |> String.downcase(), quality_value}
    end
  end

  defp find_supported_locale([]), do: nil
  defp find_supported_locale([locale | rest]) do
    # This could be enhanced to check against actually supported locales
    # For now, we'll accept common locale codes
    if locale in ["en", "es", "fr", "de", "it", "pt", "ja", "zh", "ko", "ar", "ru"] do
      locale
    else
      find_supported_locale(rest)
    end
  end

  defp supported?(_locale, nil), do: true
  defp supported?(locale, supported) when is_list(supported) do
    locale in supported
  end
  defp supported?(locale, supported) when is_function(supported, 1) do
    supported.(locale)
  end
  defp supported?(_locale, _supported), do: true
end