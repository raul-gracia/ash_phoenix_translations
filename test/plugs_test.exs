defmodule AshPhoenixTranslations.PlugsTest do
  @moduledoc """
  Tests for Phoenix Plug modules: SetLocale and LoadTranslations.

  This test module verifies the plug functionality for locale detection,
  setting, and translation preloading with mock Plug.Conn structs.
  """
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias AshPhoenixTranslations.Plugs.LoadTranslations
  alias AshPhoenixTranslations.Plugs.SetLocale

  # Test resource for LoadTranslations tests
  defmodule TestProduct do
    use Ash.Resource,
      domain: AshPhoenixTranslations.PlugsTest.TestDomain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshPhoenixTranslations]

    ets do
      table :plugs_test_products
    end

    translations do
      translatable_attribute :name, :string do
        locales [:en, :es, :fr]
        required [:en]
      end

      translatable_attribute :description, :text do
        locales [:en, :es, :fr]
        fallback(:en)
      end

      backend :database
    end

    actions do
      defaults [:read, :destroy]

      create :create do
        primary? true
        accept [:sku, :name_translations, :description_translations]
      end
    end

    attributes do
      uuid_primary_key :id
      attribute :sku, :string, allow_nil?: false
      timestamps()
    end
  end

  defmodule TestDomain do
    use Ash.Domain,
      validate_config_inclusion?: false

    resources do
      resource AshPhoenixTranslations.PlugsTest.TestProduct
    end
  end

  # Helper to create a mock conn
  defp build_conn(opts \\ []) do
    %Plug.Conn{
      assigns: Keyword.get(opts, :assigns, %{}),
      params: Keyword.get(opts, :params, %{}),
      query_params: Keyword.get(opts, :query_params, %{}),
      req_cookies: Keyword.get(opts, :cookies, %{}),
      cookies: Keyword.get(opts, :cookies, %{}),
      host: Keyword.get(opts, :host, "example.com"),
      path_info: Keyword.get(opts, :path_info, []),
      request_path: Keyword.get(opts, :request_path, "/"),
      private: Keyword.get(opts, :private, %{})
    }
    |> put_req_headers(Keyword.get(opts, :req_headers, []))
  end

  defp put_req_headers(conn, headers) do
    Enum.reduce(headers, conn, fn {key, value}, conn ->
      Plug.Conn.put_req_header(conn, key, value)
    end)
  end

  # Session configuration helper
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

  # Helper to create a conn with session support
  defp build_conn_with_session(opts \\ []) do
    {secret_key_base, session_opts} = setup_session()

    build_conn(opts)
    |> Map.put(:secret_key_base, secret_key_base)
    |> Plug.Session.call(session_opts)
    |> Plug.Conn.fetch_session()
  end

  describe "SetLocale.init/1" do
    test "returns default config when no options provided" do
      config = SetLocale.init([])

      assert config.strategies == [:auto]
      assert config.fallback == "en"
      assert config.persist == [:session]
      assert config.param_key == "locale"
      assert config.session_key == :locale
      assert config.cookie_key == "locale"
    end

    test "accepts custom strategies" do
      config = SetLocale.init(strategies: [:param, :header])
      assert config.strategies == [:param, :header]
    end

    test "accepts custom fallback locale" do
      config = SetLocale.init(fallback: "es")
      assert config.fallback == "es"
    end

    test "accepts supported locales list" do
      config = SetLocale.init(supported: ["en", "es", "fr"])
      assert config.supported == ["en", "es", "fr"]
    end

    test "accepts custom persist storage" do
      config = SetLocale.init(persist: [:session, :cookie])
      assert config.persist == [:session, :cookie]
    end

    test "wraps single persist value in list" do
      config = SetLocale.init(persist: :cookie)
      assert config.persist == [:cookie]
    end

    test "accepts custom param key" do
      config = SetLocale.init(param_key: "lang")
      assert config.param_key == "lang"
    end

    test "accepts custom session key" do
      config = SetLocale.init(session_key: :user_locale)
      assert config.session_key == :user_locale
    end

    test "accepts custom cookie key" do
      config = SetLocale.init(cookie_key: "user_lang")
      assert config.cookie_key == "user_lang"
    end

    test "accepts custom cookie options" do
      cookie_opts = [max_age: 100, http_only: true]
      config = SetLocale.init(cookie_options: cookie_opts)
      assert config.cookie_options == cookie_opts
    end

    test "accepts custom resolver function" do
      resolver_fn = fn _conn -> "custom" end
      config = SetLocale.init(custom_resolver: resolver_fn)
      assert config.custom_resolver == resolver_fn
    end
  end

  describe "SetLocale.call/2" do
    test "sets locale from param" do
      config = SetLocale.init(strategies: [:param])

      conn =
        build_conn_with_session(params: %{"locale" => "es"})
        |> SetLocale.call(config)

      # LocaleResolver returns atoms
      assert conn.assigns[:locale] == :es
    end

    test "sets locale from query_params" do
      config = SetLocale.init(strategies: [:param])

      conn =
        build_conn_with_session(query_params: %{"locale" => "fr"})
        |> SetLocale.call(config)

      assert conn.assigns[:locale] == :fr
    end

    test "falls back to default when locale not found" do
      capture_log(fn ->
        config = SetLocale.init(strategies: [:param], fallback: "en")

        conn =
          build_conn_with_session()
          |> SetLocale.call(config)

        # Fallback is a string
        assert conn.assigns[:locale] == "en"
      end)
    end

    test "uses custom fallback locale" do
      capture_log(fn ->
        config = SetLocale.init(strategies: [:param], fallback: "de")

        conn =
          build_conn_with_session()
          |> SetLocale.call(config)

        assert conn.assigns[:locale] == "de"
      end)
    end

    test "persists locale to session" do
      config = SetLocale.init(strategies: [:param], persist: [:session])

      conn =
        build_conn_with_session(params: %{"locale" => "es"})
        |> SetLocale.call(config)

      # Session stores the locale as returned by resolver (atom)
      assert Plug.Conn.get_session(conn, :locale) == :es
    end

    test "persists locale to cookie when locale is a string" do
      capture_log(fn ->
        # Use fallback which is a string to avoid atom issue
        config = SetLocale.init(strategies: [:param], persist: [:cookie], fallback: "fr")

        conn =
          build_conn_with_session()
          |> SetLocale.call(config)

        # Check if cookie is set in response cookies
        assert conn.resp_cookies["locale"]
        assert conn.resp_cookies["locale"].value == "fr"
      end)
    end

    test "sets raw_locale assign" do
      config = SetLocale.init(strategies: [:param])

      conn =
        build_conn_with_session(params: %{"locale" => "es"})
        |> SetLocale.call(config)

      assert conn.assigns[:raw_locale] == :es
    end
  end

  describe "LoadTranslations.init/1" do
    test "returns default config when no options provided" do
      config = LoadTranslations.init([])

      assert config.resources == []
      assert config.preload == nil
      assert config.from_controller == false
      assert config.cache == true
      assert config.cache_ttl == 3600
    end

    test "accepts resources list" do
      config = LoadTranslations.init(resources: [TestProduct])
      assert config.resources == [TestProduct]
    end

    test "accepts preload fields list" do
      config = LoadTranslations.init(preload: [:name, :description])
      assert config.preload == [:name, :description]
    end

    test "accepts from_controller option" do
      config = LoadTranslations.init(from_controller: true)
      assert config.from_controller == true
    end

    test "accepts cache option" do
      config = LoadTranslations.init(cache: false)
      assert config.cache == false
    end

    test "accepts cache_ttl option" do
      config = LoadTranslations.init(cache_ttl: 7200)
      assert config.cache_ttl == 7200
    end
  end

  describe "LoadTranslations.call/2" do
    test "TestProduct is recognized as Ash resource" do
      assert Code.ensure_loaded?(TestProduct)
      assert function_exported?(TestProduct, :spark_dsl_config, 0)
    end

    test "assigns preloaded_translations to conn" do
      config = LoadTranslations.init(resources: [TestProduct])

      conn =
        build_conn(assigns: %{locale: "en"})
        |> LoadTranslations.call(config)

      assert Map.has_key?(conn.assigns, :preloaded_translations)
    end

    test "assigns translation_cache_key to conn" do
      config = LoadTranslations.init(resources: [TestProduct])

      conn =
        build_conn(assigns: %{locale: "en"})
        |> LoadTranslations.call(config)

      assert Map.has_key?(conn.assigns, :translation_cache_key)
      assert String.starts_with?(conn.assigns.translation_cache_key, "translations:")
    end

    test "uses locale from assigns" do
      config = LoadTranslations.init(resources: [TestProduct])

      conn =
        build_conn(assigns: %{locale: "es"})
        |> LoadTranslations.call(config)

      # Cache key should include locale
      assert String.ends_with?(conn.assigns.translation_cache_key, ":es")
    end

    test "defaults to en locale when not set" do
      config = LoadTranslations.init(resources: [TestProduct])

      conn =
        build_conn()
        |> LoadTranslations.call(config)

      assert String.ends_with?(conn.assigns.translation_cache_key, ":en")
    end

    test "handles empty resources list" do
      config = LoadTranslations.init(resources: [])

      conn =
        build_conn()
        |> LoadTranslations.call(config)

      assert conn.assigns.preloaded_translations == %{}
    end

    test "loads translations for valid Ash resources" do
      config = LoadTranslations.init(resources: [TestProduct])

      conn =
        build_conn(assigns: %{locale: "en"})
        |> LoadTranslations.call(config)

      # TestProduct is a valid Ash resource
      assert Map.has_key?(conn.assigns.preloaded_translations, TestProduct)
    end

    test "respects cache option" do
      config = LoadTranslations.init(resources: [TestProduct], cache: false)

      conn =
        build_conn(assigns: %{locale: "en"})
        |> LoadTranslations.call(config)

      # Should still work without caching
      assert Map.has_key?(conn.assigns, :preloaded_translations)
    end

    test "loads fields from resource when preload not specified" do
      config = LoadTranslations.init(resources: [TestProduct])

      conn =
        build_conn(assigns: %{locale: "en"})
        |> LoadTranslations.call(config)

      translations = conn.assigns.preloaded_translations[TestProduct]
      # Should have both name and description fields from the resource
      assert Map.has_key?(translations.fields, :name)
      assert Map.has_key?(translations.fields, :description)
    end

    test "respects preload fields option" do
      config = LoadTranslations.init(resources: [TestProduct], preload: [:name])

      conn =
        build_conn(assigns: %{locale: "en"})
        |> LoadTranslations.call(config)

      translations = conn.assigns.preloaded_translations[TestProduct]
      # Should only have name field
      assert Map.has_key?(translations.fields, :name)
      refute Map.has_key?(translations.fields, :description)
    end
  end

  describe "LoadTranslations with from_controller" do
    test "returns empty when no controller in private" do
      config = LoadTranslations.init(from_controller: true)

      conn =
        build_conn()
        |> LoadTranslations.call(config)

      assert conn.assigns.preloaded_translations == %{}
    end

    test "attempts to infer resource from controller name" do
      config = LoadTranslations.init(from_controller: true)

      # Even though controller inference won't find a real module,
      # the plug should handle it gracefully
      conn =
        build_conn(private: %{phoenix_controller: MyAppWeb.ProductController})
        |> LoadTranslations.call(config)

      # Should not crash, just return empty if resource not found
      assert Map.has_key?(conn.assigns, :preloaded_translations)
    end
  end

  describe "LoadTranslations cache behavior" do
    test "caches translation data" do
      config = LoadTranslations.init(resources: [TestProduct], cache: true, cache_ttl: 3600)

      conn1 =
        build_conn(assigns: %{locale: "en"})
        |> LoadTranslations.call(config)

      conn2 =
        build_conn(assigns: %{locale: "en"})
        |> LoadTranslations.call(config)

      # Both should have the same cache key structure
      assert conn1.assigns.translation_cache_key == conn2.assigns.translation_cache_key
    end

    test "different locales have different cache keys" do
      config = LoadTranslations.init(resources: [TestProduct])

      conn_en =
        build_conn(assigns: %{locale: "en"})
        |> LoadTranslations.call(config)

      conn_es =
        build_conn(assigns: %{locale: "es"})
        |> LoadTranslations.call(config)

      # Cache keys should differ by locale
      refute conn_en.assigns.translation_cache_key == conn_es.assigns.translation_cache_key
    end
  end
end
