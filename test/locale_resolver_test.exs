defmodule AshPhoenixTranslations.LocaleResolverTest do
  @moduledoc """
  Tests for AshPhoenixTranslations.LocaleResolver module.

  This test module verifies locale resolution strategies including:
  - Header-based resolution (Accept-Language)
  - Parameter-based resolution
  - Session-based resolution
  - Cookie-based resolution
  - Subdomain-based resolution
  - Path-based resolution
  - User preference resolution
  - Auto strategy (tries multiple strategies in order)
  - Configuration and persistence
  """
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias AshPhoenixTranslations.LocaleResolver

  # Helper to create a mock conn
  defp build_conn(opts \\ []) do
    {secret_key_base, session_opts} = setup_session()

    conn = %Plug.Conn{
      assigns: Keyword.get(opts, :assigns, %{}),
      params: Keyword.get(opts, :params, %{}),
      query_params: Keyword.get(opts, :query_params, %{}),
      req_cookies: Keyword.get(opts, :cookies, %{}),
      cookies: Keyword.get(opts, :cookies, %{}),
      host: Keyword.get(opts, :host, "example.com"),
      path_info: Keyword.get(opts, :path_info, []),
      request_path: Keyword.get(opts, :request_path, "/"),
      private: Keyword.get(opts, :private, %{}),
      remote_ip: Keyword.get(opts, :remote_ip, {127, 0, 0, 1})
    }
    |> Map.put(:secret_key_base, secret_key_base)
    |> Plug.Session.call(session_opts)
    |> Plug.Conn.fetch_session()
    |> put_req_headers(Keyword.get(opts, :req_headers, []))

    conn
  end

  defp setup_session do
    secret_key_base = :crypto.strong_rand_bytes(64) |> Base.encode64()

    session_opts =
      Plug.Session.init(
        store: :cookie,
        key: "_test_session",
        encryption_salt: "test_encryption",
        signing_salt: "test_signing",
        secret_key_base: secret_key_base
      )

    {secret_key_base, session_opts}
  end

  defp put_req_headers(conn, headers) do
    Enum.reduce(headers, conn, fn {key, value}, conn ->
      Plug.Conn.put_req_header(conn, key, value)
    end)
  end

  describe "resolve/2 with :header strategy" do
    test "extracts locale from Accept-Language header" do
      conn = build_conn(req_headers: [{"accept-language", "es,en;q=0.9"}])

      # Returns atom locale
      assert LocaleResolver.resolve(conn, :header) == :es
    end

    test "respects quality values in Accept-Language" do
      conn = build_conn(req_headers: [{"accept-language", "en;q=0.8,es;q=0.9,fr;q=0.5"}])

      # Spanish has highest quality
      assert LocaleResolver.resolve(conn, :header) == :es
    end

    test "returns nil when no Accept-Language header" do
      conn = build_conn()

      assert LocaleResolver.resolve(conn, :header) == nil
    end

    test "handles complex Accept-Language header" do
      conn = build_conn(req_headers: [{"accept-language", "en-US,en;q=0.9,es-MX;q=0.8"}])

      assert LocaleResolver.resolve(conn, :header) == :en
    end

    test "filters unsupported locales" do
      # xyz is not in supported locales
      conn = build_conn(req_headers: [{"accept-language", "xyz,en;q=0.5"}])

      # Should fall back to en since xyz is not supported
      assert LocaleResolver.resolve(conn, :header) == :en
    end

    test "sanitizes malicious input in Accept-Language" do
      conn = build_conn(req_headers: [{"accept-language", "en<script>;q=0.9"}])

      # Should sanitize and still work
      result = LocaleResolver.resolve(conn, :header)
      # Should either return :en or nil (sanitized)
      assert result == :en or result == nil
    end
  end

  describe "resolve/2 with :param strategy" do
    test "extracts locale from params" do
      conn = build_conn(params: %{"locale" => "es"})

      assert LocaleResolver.resolve(conn, :param) == :es
    end

    test "extracts locale from query_params" do
      conn = build_conn(query_params: %{"locale" => "fr"})

      assert LocaleResolver.resolve(conn, :param) == :fr
    end

    test "returns nil when no locale param" do
      conn = build_conn()

      # Capture log to suppress expected warning when param is nil
      capture_log(fn ->
        assert LocaleResolver.resolve(conn, :param) == nil
      end)
    end

    test "validates locale from params" do
      conn = build_conn(params: %{"locale" => "invalid_locale_xyz"})

      # Capture log to suppress expected warning about invalid locale
      capture_log(fn ->
        # Should return nil for invalid locale
        assert LocaleResolver.resolve(conn, :param) == nil
      end)
    end

    test "rejects malicious locale input" do
      conn = build_conn(params: %{"locale" => "<script>alert('xss')</script>"})

      # Capture log to suppress expected warning about invalid locale
      capture_log(fn ->
        assert LocaleResolver.resolve(conn, :param) == nil
      end)
    end
  end

  describe "resolve/2 with :session strategy" do
    test "extracts locale from session" do
      conn =
        build_conn()
        |> Plug.Conn.put_session(:locale, "es")

      assert LocaleResolver.resolve(conn, :session) == :es
    end

    test "returns nil when no session locale" do
      conn = build_conn()

      assert LocaleResolver.resolve(conn, :session) == nil
    end

    test "validates locale from session" do
      conn =
        build_conn()
        |> Plug.Conn.put_session(:locale, "invalid_locale")

      # Capture log to suppress expected warning about invalid locale
      capture_log(fn ->
        assert LocaleResolver.resolve(conn, :session) == nil
      end)
    end
  end

  describe "resolve/2 with :cookie strategy" do
    test "extracts locale from cookie" do
      conn = build_conn(cookies: %{"locale" => "fr"})

      assert LocaleResolver.resolve(conn, :cookie) == :fr
    end

    test "returns nil when no locale cookie" do
      conn = build_conn()

      assert LocaleResolver.resolve(conn, :cookie) == nil
    end

    test "validates locale from cookie" do
      conn = build_conn(cookies: %{"locale" => "invalid_locale"})

      # Capture log to suppress expected warning about invalid locale
      capture_log(fn ->
        assert LocaleResolver.resolve(conn, :cookie) == nil
      end)
    end
  end

  describe "resolve/2 with :subdomain strategy" do
    test "extracts locale from subdomain" do
      conn = build_conn(host: "es.example.com")

      assert LocaleResolver.resolve(conn, :subdomain) == :es
    end

    test "returns nil for non-locale subdomain" do
      conn = build_conn(host: "www.example.com")

      # Capture log to suppress expected warning about invalid subdomain locale
      capture_log(fn ->
        assert LocaleResolver.resolve(conn, :subdomain) == nil
      end)
    end

    test "returns nil for bare domain" do
      conn = build_conn(host: "example.com")

      # 'example' is not a valid locale
      # Capture log to suppress expected warning about invalid subdomain locale
      capture_log(fn ->
        assert LocaleResolver.resolve(conn, :subdomain) == nil
      end)
    end
  end

  describe "resolve/2 with :path strategy" do
    test "extracts locale from URL path" do
      conn = build_conn(path_info: ["es", "products"])

      assert LocaleResolver.resolve(conn, :path) == :es
    end

    test "returns nil for non-locale path prefix" do
      conn = build_conn(path_info: ["products", "123"])

      # Capture log to suppress expected warning about invalid path locale
      capture_log(fn ->
        assert LocaleResolver.resolve(conn, :path) == nil
      end)
    end

    test "returns nil for empty path" do
      conn = build_conn(path_info: [])

      assert LocaleResolver.resolve(conn, :path) == nil
    end
  end

  describe "resolve/2 with :user strategy" do
    test "extracts locale from current_user locale field" do
      user = %{locale: "de"}
      conn = build_conn(assigns: %{current_user: user})

      assert LocaleResolver.resolve(conn, :user) == :de
    end

    test "extracts locale from current_user preferred_locale field" do
      user = %{preferred_locale: "it"}
      conn = build_conn(assigns: %{current_user: user})

      assert LocaleResolver.resolve(conn, :user) == :it
    end

    test "returns nil when no current_user" do
      conn = build_conn()

      assert LocaleResolver.resolve(conn, :user) == nil
    end

    test "returns nil when user has no locale preference" do
      user = %{name: "Test User"}
      conn = build_conn(assigns: %{current_user: user})

      assert LocaleResolver.resolve(conn, :user) == nil
    end

    test "validates user locale" do
      user = %{locale: "invalid_locale"}
      conn = build_conn(assigns: %{current_user: user})

      assert LocaleResolver.resolve(conn, :user) == nil
    end
  end

  describe "resolve/2 with :auto strategy" do
    test "tries strategies in order and returns first match" do
      # Param takes precedence
      conn = build_conn(params: %{"locale" => "es"}, req_headers: [{"accept-language", "fr"}])

      assert LocaleResolver.resolve(conn, :auto) == :es
    end

    test "falls back to header when no param" do
      conn = build_conn(req_headers: [{"accept-language", "fr"}])

      # Capture log to suppress expected warnings from auto strategy checking multiple sources
      capture_log(fn ->
        assert LocaleResolver.resolve(conn, :auto) == :fr
      end)
    end

    test "uses path locale when available" do
      conn = build_conn(path_info: ["de", "products"])

      # Capture log to suppress expected warnings from auto strategy checking multiple sources
      capture_log(fn ->
        assert LocaleResolver.resolve(conn, :auto) == :de
      end)
    end

    test "uses session when no param or path" do
      conn =
        build_conn()
        |> Plug.Conn.put_session(:locale, "it")

      # Capture log to suppress expected warnings from auto strategy checking multiple sources
      capture_log(fn ->
        assert LocaleResolver.resolve(conn, :auto) == :it
      end)
    end

    test "returns nil when no strategy matches" do
      conn = build_conn()

      # Capture log to suppress expected warnings from auto strategy checking multiple sources
      capture_log(fn ->
        assert LocaleResolver.resolve(conn, :auto) == nil
      end)
    end
  end

  describe "resolve/2 with custom function" do
    test "accepts custom resolver function" do
      custom_resolver = fn _conn -> "custom" end
      conn = build_conn()

      # Note: custom function returns raw value
      result = LocaleResolver.resolve(conn, custom_resolver)
      assert result == "custom"
    end
  end

  describe "configure/1" do
    test "returns configuration map" do
      config =
        LocaleResolver.configure(
          strategies: [:param, :header],
          fallback: "es",
          supported: ["en", "es", "fr"]
        )

      assert config.strategies == [:param, :header]
      assert config.fallback == "es"
      assert config.supported == ["en", "es", "fr"]
    end

    test "provides default values" do
      config = LocaleResolver.configure([])

      assert config.strategies == [:auto]
      assert config.fallback == "en"
      assert config.supported == nil
    end

    test "accepts custom resolver" do
      custom_fn = fn _conn -> "custom" end
      config = LocaleResolver.configure(custom: custom_fn)

      assert config.custom == custom_fn
    end
  end

  describe "resolve_with_config/2" do
    test "uses configured strategies" do
      config = LocaleResolver.configure(strategies: [:param], fallback: "en")
      conn = build_conn(params: %{"locale" => "es"})

      assert LocaleResolver.resolve_with_config(conn, config) == :es
    end

    test "applies fallback when no match" do
      config = LocaleResolver.configure(strategies: [:param], fallback: "de")
      conn = build_conn()

      # Capture log to suppress expected warning when param is nil
      capture_log(fn ->
        assert LocaleResolver.resolve_with_config(conn, config) == "de"
      end)
    end

    test "respects supported locales" do
      config = LocaleResolver.configure(strategies: [:param], fallback: "en", supported: [:en, :es])

      # fr is not in supported list
      conn = build_conn(params: %{"locale" => "fr"})

      # Should fall back to default since fr not in supported list
      assert LocaleResolver.resolve_with_config(conn, config) == "en"
    end

    test "uses custom resolver when strategy is :custom" do
      custom_fn = fn _conn -> :es end
      config = LocaleResolver.configure(strategies: [:custom], custom: custom_fn, fallback: "en", supported: [:en, :es])
      conn = build_conn()

      result = LocaleResolver.resolve_with_config(conn, config)
      assert result == :es
    end
  end

  describe "persist/3" do
    test "persists locale to session" do
      conn = build_conn()

      result = LocaleResolver.persist(conn, "es", :session)

      assert Plug.Conn.get_session(result, :locale) == "es"
    end

    test "persists locale to cookie" do
      conn = build_conn()

      result = LocaleResolver.persist(conn, "fr", :cookie)

      assert result.resp_cookies["locale"]
      assert result.resp_cookies["locale"].value == "fr"
    end

    test "persists to multiple storage types" do
      conn = build_conn()

      result = LocaleResolver.persist(conn, "de", [:session, :cookie])

      assert Plug.Conn.get_session(result, :locale) == "de"
      assert result.resp_cookies["locale"].value == "de"
    end

    test "handles unsupported storage gracefully" do
      conn = build_conn()

      # Should not crash
      result = LocaleResolver.persist(conn, "en", :unknown_storage)
      assert result == conn
    end
  end

  describe "Accept-Language parsing edge cases" do
    test "handles single locale without quality" do
      conn = build_conn(req_headers: [{"accept-language", "en"}])

      assert LocaleResolver.resolve(conn, :header) == :en
    end

    test "handles locale with regional variant" do
      conn = build_conn(req_headers: [{"accept-language", "en-GB"}])

      assert LocaleResolver.resolve(conn, :header) == :en
    end

    test "handles multiple locales with varying qualities" do
      conn = build_conn(req_headers: [{"accept-language", "de;q=0.7,en;q=0.5,fr;q=0.9"}])

      assert LocaleResolver.resolve(conn, :header) == :fr
    end

    test "handles empty Accept-Language" do
      conn = build_conn(req_headers: [{"accept-language", ""}])

      assert LocaleResolver.resolve(conn, :header) == nil
    end

    test "handles whitespace in Accept-Language" do
      conn = build_conn(req_headers: [{"accept-language", "  en  ,  es;q=0.9  "}])

      result = LocaleResolver.resolve(conn, :header)
      assert result == :en
    end

    test "ignores invalid quality values" do
      conn = build_conn(req_headers: [{"accept-language", "en;q=invalid,es;q=0.9"}])

      # en has invalid quality (0.0), es should win
      result = LocaleResolver.resolve(conn, :header)
      assert result == :es
    end
  end

  describe "security - input validation" do
    test "rejects locale with newline characters" do
      conn = build_conn(params: %{"locale" => "en\nmalicious"})

      # Capture log to suppress expected warning about invalid locale
      capture_log(fn ->
        assert LocaleResolver.resolve(conn, :param) == nil
      end)
    end

    test "rejects locale with null bytes" do
      conn = build_conn(params: %{"locale" => "en\0malicious"})

      # Capture log to suppress expected warning about invalid locale
      capture_log(fn ->
        assert LocaleResolver.resolve(conn, :param) == nil
      end)
    end

    test "rejects locale with shell metacharacters" do
      conn = build_conn(params: %{"locale" => "en;rm -rf /"})

      # Capture log to suppress expected warning about invalid locale
      capture_log(fn ->
        assert LocaleResolver.resolve(conn, :param) == nil
      end)
    end

    test "rejects overly long locale string" do
      long_locale = String.duplicate("a", 1000)
      conn = build_conn(params: %{"locale" => long_locale})

      # Capture log to suppress expected warning about invalid locale
      capture_log(fn ->
        assert LocaleResolver.resolve(conn, :param) == nil
      end)
    end
  end
end
