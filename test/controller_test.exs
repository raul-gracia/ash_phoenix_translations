defmodule AshPhoenixTranslations.ControllerTest do
  @moduledoc """
  Tests for AshPhoenixTranslations.Controller module.

  This test module verifies controller helpers for translation management,
  locale handling, and integration with Plug.Conn.
  """
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import AshPhoenixTranslations.Controller

  # Test resource
  defmodule TestProduct do
    use Ash.Resource,
      domain: AshPhoenixTranslations.ControllerTest.TestDomain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshPhoenixTranslations]

    ets do
      table :controller_test_products
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

      update :update do
        primary? true
        accept [:sku, :name_translations, :description_translations]
        require_atomic? false
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
      resource AshPhoenixTranslations.ControllerTest.TestProduct
    end
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

  # Helper to create a mock conn with session support
  defp build_conn(opts \\ []) do
    {secret_key_base, session_opts} = setup_session()

    %Plug.Conn{
      assigns: Keyword.get(opts, :assigns, %{}),
      params: Keyword.get(opts, :params, %{}),
      query_params: Keyword.get(opts, :query_params, %{}),
      req_cookies: Keyword.get(opts, :cookies, %{}),
      cookies: Keyword.get(opts, :cookies, %{}),
      host: Keyword.get(opts, :host, "example.com"),
      path_info: Keyword.get(opts, :path_info, []),
      request_path: Keyword.get(opts, :request_path, "/products"),
      private: Keyword.get(opts, :private, %{})
    }
    |> Map.put(:secret_key_base, secret_key_base)
    |> Plug.Session.call(session_opts)
    |> Plug.Conn.fetch_session()
    |> put_req_headers(Keyword.get(opts, :req_headers, []))
  end

  defp put_req_headers(conn, headers) do
    Enum.reduce(headers, conn, fn {key, value}, conn ->
      Plug.Conn.put_req_header(conn, key, value)
    end)
  end

  setup do
    # Clean ETS table before each test
    if :ets.whereis(:controller_test_products) != :undefined do
      :ets.delete_all_objects(:controller_test_products)
    end

    :ok
  end

  describe "set_locale/2 with binary locale" do
    test "sets locale in session" do
      conn = build_conn() |> set_locale("es")

      assert Plug.Conn.get_session(conn, :locale) == "es"
    end

    test "sets locale in assigns" do
      conn = build_conn() |> set_locale("fr")

      assert conn.assigns[:locale] == "fr"
    end

    test "converts atom to string" do
      conn = build_conn() |> set_locale(:de)

      assert conn.assigns[:locale] == "de"
      assert Plug.Conn.get_session(conn, :locale) == "de"
    end
  end

  describe "set_locale/2 with options" do
    test "uses resolver to detect locale" do
      conn =
        build_conn(params: %{"locale" => "es"})
        |> set_locale(resolver: :param)

      # LocaleResolver returns atoms
      assert conn.assigns[:locale] == :es
    end

    test "uses fallback when locale not detected" do
      capture_log(fn ->
        conn =
          build_conn()
          |> set_locale(resolver: :param, fallback: "de")

        assert conn.assigns[:locale] == "de"
      end)
    end

    test "defaults to auto resolver" do
      capture_log(fn ->
        conn =
          build_conn()
          |> set_locale(fallback: "en")

        assert conn.assigns[:locale] == "en"
      end)
    end
  end

  describe "get_locale/1" do
    test "returns locale from assigns" do
      conn = build_conn(assigns: %{locale: "es"})

      assert get_locale(conn) == "es"
    end

    test "falls back to session when not in assigns" do
      conn =
        build_conn()
        |> Plug.Conn.put_session(:locale, "fr")

      assert get_locale(conn) == "fr"
    end

    test "defaults to en when no locale found" do
      capture_log(fn ->
        conn = build_conn()

        assert get_locale(conn) == "en"
      end)
    end

    test "prefers assigns over session" do
      conn =
        build_conn(assigns: %{locale: "es"})
        |> Plug.Conn.put_session(:locale, "fr")

      assert get_locale(conn) == "es"
    end
  end

  describe "with_locale/2" do
    test "translates resource to current locale using atom" do
      {:ok, product} =
        TestProduct
        |> Ash.Changeset.for_create(:create, %{
          sku: "TEST-001",
          name_translations: %{en: "English Name", es: "Nombre en Espanol"}
        })
        |> Ash.create()

      # Use atom locale in assigns since translate/2 requires atoms
      conn = build_conn(assigns: %{locale: :es})
      translated = with_locale(conn, product)

      assert translated.name == "Nombre en Espanol"
    end

    test "translates list of resources using translate_all" do
      # with_locale is designed for single resources
      # Use AshPhoenixTranslations.translate_all/2 for lists
      {:ok, p1} =
        TestProduct
        |> Ash.Changeset.for_create(:create, %{
          sku: "TEST-001",
          name_translations: %{en: "Product 1", es: "Producto 1"}
        })
        |> Ash.create()

      {:ok, p2} =
        TestProduct
        |> Ash.Changeset.for_create(:create, %{
          sku: "TEST-002",
          name_translations: %{en: "Product 2", es: "Producto 2"}
        })
        |> Ash.create()

      conn = build_conn(assigns: %{locale: :es})
      translated = AshPhoenixTranslations.translate_all([p1, p2], conn)

      assert length(translated) == 2
      assert Enum.at(translated, 0).name == "Producto 1"
      assert Enum.at(translated, 1).name == "Producto 2"
    end
  end

  describe "available_locales/1" do
    test "returns supported locales for resource" do
      locales = available_locales(TestProduct)

      assert :en in locales
      assert :es in locales
      assert :fr in locales
    end
  end

  describe "locale_supported?/2" do
    test "returns true for supported locale atom" do
      assert locale_supported?(TestProduct, :en) == true
      assert locale_supported?(TestProduct, :es) == true
    end

    test "returns true for supported locale string" do
      assert locale_supported?(TestProduct, "en") == true
      assert locale_supported?(TestProduct, "es") == true
    end

    test "returns false for unsupported locale" do
      # zh is not in the test resource locales
      assert locale_supported?(TestProduct, :zh) == false
    end
  end

  describe "translation_errors/1" do
    test "extracts translation-related errors from changeset" do
      # Create a changeset with translation errors
      changeset = %Ash.Changeset{
        errors: [
          %{field: :name_translations, message: "Spanish translation is required"},
          %{field: :sku, message: "can't be blank"},
          %{field: :description_translations, message: "missing French translation"}
        ]
      }

      errors = translation_errors(changeset)

      assert length(errors) == 2
      assert {:name, "Spanish translation is required"} in errors
      assert {:description, "missing French translation"} in errors
    end

    test "returns empty list when no translation errors" do
      changeset = %Ash.Changeset{
        errors: [
          %{field: :sku, message: "can't be blank"},
          %{field: :price, message: "must be positive"}
        ]
      }

      errors = translation_errors(changeset)
      assert errors == []
    end
  end

  describe "locale_switcher/2" do
    test "returns locale switcher data" do
      conn = build_conn(assigns: %{locale: "en"}, query_params: %{})
      switcher = locale_switcher(conn, TestProduct)

      assert is_list(switcher)
      assert length(switcher) == 3

      # Find English entry
      en_entry = Enum.find(switcher, &(&1.code == "en"))
      assert en_entry.active == true
      assert en_entry.name == "English"

      # Find Spanish entry - uses proper accented name
      es_entry = Enum.find(switcher, &(&1.code == "es"))
      assert es_entry.active == false
      # Controller uses accented names
      assert es_entry.name == "Español"
    end

    test "includes URL with locale parameter" do
      conn = build_conn(assigns: %{locale: "en"}, request_path: "/products", query_params: %{})
      switcher = locale_switcher(conn, TestProduct)

      es_entry = Enum.find(switcher, &(&1.code == "es"))
      assert es_entry.url =~ "locale=es"
    end

    test "preserves existing query params in URL" do
      conn =
        build_conn(
          assigns: %{locale: "en"},
          request_path: "/products",
          query_params: %{"page" => "2"}
        )

      switcher = locale_switcher(conn, TestProduct)

      es_entry = Enum.find(switcher, &(&1.code == "es"))
      assert es_entry.url =~ "locale=es"
      assert es_entry.url =~ "page=2"
    end
  end

  describe "set_translation_context/1" do
    test "returns context map with locale" do
      conn = build_conn(assigns: %{locale: "es"})
      context = set_translation_context(conn)

      assert context.locale == "es"
    end

    test "includes actor from assigns" do
      user = %{id: 1, name: "Test User"}
      conn = build_conn(assigns: %{locale: "en", current_user: user})
      context = set_translation_context(conn)

      assert context.actor == user
    end

    test "includes private translation context" do
      conn = build_conn(assigns: %{locale: "fr"})
      context = set_translation_context(conn)

      assert context.private.ash_phoenix_translations.locale == "fr"
      assert context.private.ash_phoenix_translations.conn == conn
    end
  end

  describe "locale name mapping" do
    test "locale_switcher uses correct display names with accents" do
      conn = build_conn(assigns: %{locale: "en"}, query_params: %{})
      switcher = locale_switcher(conn, TestProduct)

      en_entry = Enum.find(switcher, &(&1.code == "en"))
      assert en_entry.name == "English"

      es_entry = Enum.find(switcher, &(&1.code == "es"))
      # Controller uses accented name
      assert es_entry.name == "Español"

      fr_entry = Enum.find(switcher, &(&1.code == "fr"))
      assert fr_entry.name == "Français"
    end
  end
end
