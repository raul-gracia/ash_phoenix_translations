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
  require Logger

  alias AshPhoenixTranslations.LocaleValidator

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
    locale = conn.params["locale"] || conn.query_params["locale"]

    case LocaleValidator.validate_locale(locale) do
      {:ok, valid_locale} ->
        valid_locale

      {:error, _} ->
        Logger.warning("Invalid locale in request parameters",
          locale: inspect(locale),
          ip: get_client_ip(conn)
        )

        nil
    end
  end

  def resolve(conn, :session) do
    case get_session(conn, :locale) do
      nil ->
        nil

      locale ->
        case LocaleValidator.validate_locale(locale) do
          {:ok, valid} ->
            valid

          {:error, _} ->
            Logger.warning("Invalid locale in session", locale: inspect(locale))
            nil
        end
    end
  end

  def resolve(conn, :cookie) do
    case conn.cookies["locale"] do
      nil ->
        nil

      locale ->
        case LocaleValidator.validate_locale(locale) do
          {:ok, valid} ->
            valid

          {:error, _} ->
            Logger.warning("Invalid locale in cookie", locale: inspect(locale))
            nil
        end
    end
  end

  def resolve(conn, :subdomain) do
    case String.split(conn.host, ".") do
      [subdomain | _rest] ->
        case LocaleValidator.validate_locale(subdomain) do
          {:ok, locale} ->
            locale

          {:error, _} ->
            Logger.warning("Invalid subdomain locale", subdomain: subdomain)
            nil
        end

      _ ->
        nil
    end
  end

  def resolve(conn, :path) do
    case conn.path_info do
      [path_locale | _rest] ->
        case LocaleValidator.validate_locale(path_locale) do
          {:ok, locale} ->
            locale

          {:error, _} ->
            Logger.warning("Invalid path locale", path_locale: path_locale)
            nil
        end

      _ ->
        nil
    end
  end

  def resolve(conn, :user) do
    case conn.assigns[:current_user] do
      %{locale: locale} when not is_nil(locale) ->
        case LocaleValidator.validate_locale(locale) do
          {:ok, valid} -> valid
          {:error, _} -> nil
        end

      %{preferred_locale: locale} when not is_nil(locale) ->
        case LocaleValidator.validate_locale(locale) do
          {:ok, valid} -> valid
          {:error, _} -> nil
        end

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
    # Filter out invalid locales
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(fn {_lang, quality} -> quality end, :desc)
    |> Enum.map(fn {lang, _quality} -> lang end)
  end

  defp parse_accept_language(_), do: []

  defp parse_language_tag(tag) do
    # SECURITY: Sanitize input to prevent injection
    sanitized = String.replace(tag, ~r/[^a-zA-Z0-9,;=.\-]/, "")

    case String.split(sanitized, ";") do
      [lang] ->
        parsed_lang =
          lang |> String.trim() |> String.split("-") |> List.first() |> String.downcase()

        case LocaleValidator.validate_locale(parsed_lang) do
          {:ok, locale} -> {locale, 1.0}
          {:error, _} -> nil
        end

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

        parsed_lang =
          lang |> String.trim() |> String.split("-") |> List.first() |> String.downcase()

        case LocaleValidator.validate_locale(parsed_lang) do
          {:ok, locale} -> {locale, quality_value}
          {:error, _} -> nil
        end

      _ ->
        nil
    end
  end

  defp find_supported_locale([]), do: nil

  defp find_supported_locale([locale | rest]) do
    # Locale is already validated by parse_language_tag, just check if supported
    supported = LocaleValidator.get_supported_locales()

    if locale in supported do
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

  defp get_client_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [ip | _] ->
        ip

      [] ->
        case :inet.ntoa(conn.remote_ip) do
          {:error, _} -> "unknown"
          ip_charlist -> to_string(ip_charlist)
        end
    end
  end
end
