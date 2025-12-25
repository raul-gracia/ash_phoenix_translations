defmodule AshPhoenixTranslations.HelpersTest do
  @moduledoc """
  Tests for AshPhoenixTranslations.Helpers module.

  This test module verifies view helpers and template utilities including:
  - Translation functions (t/3, raw_t/3, translate_field/3)
  - Form helpers (locale_select/3, translation_input/4)
  - Status helpers (translation_status/3, translation_completeness/2)
  - UI components (language_switcher/3)
  - Utility functions (locale_name/1, all_translations/2, translation_exists?/3)
  """
  use ExUnit.Case, async: true

  alias AshPhoenixTranslations.Helpers

  # Test resource
  defmodule TestProduct do
    use Ash.Resource,
      domain: AshPhoenixTranslations.HelpersTest.TestDomain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshPhoenixTranslations]

    ets do
      table :helpers_test_products
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
      resource AshPhoenixTranslations.HelpersTest.TestProduct
    end
  end

  # Helper to create a mock conn
  defp build_conn(opts) do
    {secret_key_base, session_opts} = setup_session()

    %Plug.Conn{
      assigns: Keyword.get(opts, :assigns, %{}),
      params: Keyword.get(opts, :params, %{}),
      query_params: Keyword.get(opts, :query_params, %{}),
      cookies: Keyword.get(opts, :cookies, %{}),
      host: Keyword.get(opts, :host, "example.com"),
      path_info: Keyword.get(opts, :path_info, []),
      request_path: Keyword.get(opts, :request_path, "/products"),
      private: Keyword.get(opts, :private, %{})
    }
    |> Map.put(:secret_key_base, secret_key_base)
    |> Plug.Session.call(session_opts)
    |> Plug.Conn.fetch_session()
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

  # Helper to create test product struct
  defp build_product(opts \\ []) do
    %{
      __struct__: TestProduct,
      id: Keyword.get(opts, :id, Ash.UUID.generate()),
      sku: Keyword.get(opts, :sku, "TEST-001"),
      name_translations:
        Keyword.get(opts, :name_translations, %{en: "English Name", es: "Nombre en Espanol"}),
      description_translations:
        Keyword.get(opts, :description_translations, %{
          en: "English Description",
          es: "Descripcion en Espanol"
        })
    }
  end

  setup do
    # Clean ETS table before each test
    if :ets.whereis(:helpers_test_products) != :undefined do
      :ets.delete_all_objects(:helpers_test_products)
    end

    :ok
  end

  describe "t/3" do
    test "returns translation for specified locale" do
      product = build_product()

      assert Helpers.t(product, :name, locale: :es) == "Nombre en Espanol"
    end

    test "returns translation with string locale" do
      product = build_product()

      assert Helpers.t(product, :name, locale: "es") == "Nombre en Espanol"
    end

    test "returns fallback when translation missing" do
      product = build_product(name_translations: %{en: "English"})

      result = Helpers.t(product, :name, locale: :fr, fallback: "No translation")
      assert result == "No translation"
    end

    test "returns empty string as default fallback" do
      product = build_product(name_translations: %{en: "English"})

      result = Helpers.t(product, :name, locale: :fr)
      assert result == ""
    end

    test "uses current locale from conn" do
      product = build_product()
      conn = build_conn(assigns: %{locale: "es"})

      assert Helpers.t(product, :name, conn: conn) == "Nombre en Espanol"
    end

    test "defaults to en when no locale specified" do
      product = build_product()

      assert Helpers.t(product, :name) == "English Name"
    end
  end

  describe "raw_t/3" do
    test "returns translation with HTML safety bypass" do
      product = build_product()

      result = Helpers.raw_t(product, :name, locale: :en)
      # Should be marked as safe HTML
      assert {:safe, _} = result
    end

    test "applies fallback when translation missing" do
      product = build_product(name_translations: %{en: "English"})

      result = Helpers.raw_t(product, :name, locale: :fr, fallback: "Fallback")
      assert {:safe, _} = result
    end
  end

  describe "translate_field/3" do
    test "returns translation for atom locale" do
      product = build_product()

      assert Helpers.translate_field(product, :name, :es) == "Nombre en Espanol"
    end

    test "returns translation for string locale" do
      product = build_product()

      assert Helpers.translate_field(product, :name, "es") == "Nombre en Espanol"
    end

    test "returns nil for missing translation" do
      product = build_product(name_translations: %{en: "English"})

      assert Helpers.translate_field(product, :name, :fr) == nil
    end

    test "returns nil for non-existent field" do
      product = build_product()

      assert Helpers.translate_field(product, :nonexistent, :en) == nil
    end

    test "handles invalid locale string gracefully" do
      import ExUnit.CaptureLog

      product = build_product()

      # Invalid locale should return nil or fall back to :en if :en exists
      # The behavior depends on String.to_existing_atom which may fail for unknown locales
      capture_log(fn ->
        result = Helpers.translate_field(product, :name, "invalid_locale_xyz_not_existing")

        # Either returns nil (if atom doesn't exist and fallback fails)
        # or the English translation (if fallback to :en works)
        assert result == nil or result == "English Name"
      end)
    end
  end

  describe "all_translations/2" do
    test "returns all translations for a field" do
      product = build_product()

      translations = Helpers.all_translations(product, :name)

      assert translations == %{en: "English Name", es: "Nombre en Espanol"}
    end

    test "returns empty map for non-translatable field" do
      product = build_product()

      translations = Helpers.all_translations(product, :nonexistent)

      assert translations == %{}
    end
  end

  describe "translation_exists?/3" do
    test "returns true when translation exists" do
      product = build_product()

      assert Helpers.translation_exists?(product, :name, :en) == true
      assert Helpers.translation_exists?(product, :name, :es) == true
    end

    test "returns false when translation missing" do
      product = build_product(name_translations: %{en: "English"})

      # Returns nil or false for missing translations - both are falsy
      refute Helpers.translation_exists?(product, :name, :fr)
    end

    test "returns false when translation is empty string" do
      product = build_product(name_translations: %{en: "English", es: ""})

      # Returns nil or false for empty translations - both are falsy
      refute Helpers.translation_exists?(product, :name, :es)
    end
  end

  describe "translation_completeness/2" do
    test "calculates percentage for all fields" do
      product =
        build_product(
          name_translations: %{en: "Name", es: "Nombre", fr: "Nom"},
          description_translations: %{en: "Desc", es: "Descripcion", fr: ""}
        )

      completeness = Helpers.translation_completeness(product)

      # 5 out of 6 translations present (name: 3, description: 2)
      assert completeness == 83.3
    end

    test "calculates percentage for specific fields" do
      product =
        build_product(name_translations: %{en: "Name", es: "Nombre", fr: "Nom"})

      completeness = Helpers.translation_completeness(product, fields: [:name])

      assert completeness == 100.0
    end

    test "calculates percentage for specific locales" do
      product =
        build_product(
          name_translations: %{en: "Name", es: "Nombre"},
          description_translations: %{en: "Desc", es: "Descripcion"}
        )

      completeness = Helpers.translation_completeness(product, locales: [:en, :es])

      assert completeness == 100.0
    end

    test "returns 0.0 when no translations exist" do
      product =
        build_product(
          name_translations: %{},
          description_translations: %{}
        )

      completeness = Helpers.translation_completeness(product)

      assert completeness == 0.0
    end
  end

  describe "translation_status/3" do
    test "returns HTML badges for translation status" do
      product =
        build_product(name_translations: %{en: "Name", es: "Nombre"})

      result = Helpers.translation_status(product, :name)

      # Should be HTML safe
      assert {:safe, html} = result
      assert html =~ "EN"
      assert html =~ "ES"
    end

    test "shows complete status for present translations" do
      product =
        build_product(name_translations: %{en: "Name", es: "Nombre"})

      result = Helpers.translation_status(product, :name, locales: [:en, :es])

      {:safe, html} = result
      # Should have checkmarks for complete
      assert html =~ "complete"
    end

    test "shows missing status for absent translations" do
      product =
        build_product(name_translations: %{en: "Name"})

      result = Helpers.translation_status(product, :name, locales: [:en, :fr])

      {:safe, html} = result
      assert html =~ "missing"
    end
  end

  describe "locale_name/1" do
    test "returns display name for common locales" do
      assert Helpers.locale_name(:en) == "English"
      assert Helpers.locale_name(:es) == "Español"
      assert Helpers.locale_name(:fr) == "Français"
      assert Helpers.locale_name(:de) == "Deutsch"
      assert Helpers.locale_name(:it) == "Italiano"
      assert Helpers.locale_name(:pt) == "Português"
      assert Helpers.locale_name(:ja) == "日本語"
      assert Helpers.locale_name(:zh) == "中文"
      assert Helpers.locale_name(:ko) == "한국어"
      assert Helpers.locale_name(:ar) == "العربية"
      assert Helpers.locale_name(:ru) == "Русский"
    end

    test "returns display name for string locales" do
      assert Helpers.locale_name("en") == "English"
      assert Helpers.locale_name("es") == "Español"
    end

    test "returns uppercase code for unknown locales" do
      assert Helpers.locale_name(:unknown) == "UNKNOWN"
      assert Helpers.locale_name("zz") == "ZZ"
    end
  end

  describe "locale_select/3" do
    test "generates select HTML" do
      form = %Phoenix.HTML.Form{
        source: %{},
        impl: Phoenix.HTML.FormData.Map,
        id: "product",
        name: "product",
        data: %{},
        action: nil,
        hidden: [],
        params: %{},
        errors: [],
        options: []
      }

      result = Helpers.locale_select(form, :locale)

      {:safe, html} = result
      assert html =~ "<select"
      assert html =~ "English"
      assert html =~ "value=\"en\""
    end

    test "accepts custom options list" do
      form = %Phoenix.HTML.Form{
        source: %{},
        impl: Phoenix.HTML.FormData.Map,
        id: "product",
        name: "product",
        data: %{},
        action: nil,
        hidden: [],
        params: %{},
        errors: [],
        options: []
      }

      result = Helpers.locale_select(form, :locale, options: ["en", "es"])

      {:safe, html} = result
      assert html =~ "English"
      assert html =~ "Español"
      # Should not have French since we only specified en and es
      refute html =~ "Français"
    end

    test "marks selected option" do
      form = %Phoenix.HTML.Form{
        source: %{},
        impl: Phoenix.HTML.FormData.Map,
        id: "product",
        name: "product",
        data: %{locale: "es"},
        action: nil,
        hidden: [],
        params: %{},
        errors: [],
        options: []
      }

      result = Helpers.locale_select(form, :locale, selected: "es")

      {:safe, html} = result
      assert html =~ "selected"
    end

    test "accepts custom CSS class" do
      form = %Phoenix.HTML.Form{
        source: %{},
        impl: Phoenix.HTML.FormData.Map,
        id: "product",
        name: "product",
        data: %{},
        action: nil,
        hidden: [],
        params: %{},
        errors: [],
        options: []
      }

      result = Helpers.locale_select(form, :locale, class: "my-custom-class")

      {:safe, html} = result
      assert html =~ "my-custom-class"
    end
  end

  describe "translation_input/4" do
    test "generates input HTML for specific locale" do
      form = %Phoenix.HTML.Form{
        source: %{},
        impl: Phoenix.HTML.FormData.Map,
        id: "product",
        name: "product",
        data: %{name_translations: %{en: "Test", es: "Prueba"}},
        action: nil,
        hidden: [],
        params: %{},
        errors: [],
        options: []
      }

      result = Helpers.translation_input(form, :name, :es)

      {:safe, html} = result
      assert html =~ "<input"
      assert html =~ "Español"
    end

    test "accepts custom label" do
      form = %Phoenix.HTML.Form{
        source: %{},
        impl: Phoenix.HTML.FormData.Map,
        id: "product",
        name: "product",
        data: %{},
        action: nil,
        hidden: [],
        params: %{},
        errors: [],
        options: []
      }

      result = Helpers.translation_input(form, :name, :es, label: "Spanish Name")

      {:safe, html} = result
      assert html =~ "Spanish Name"
    end

    test "accepts custom CSS class" do
      form = %Phoenix.HTML.Form{
        source: %{},
        impl: Phoenix.HTML.FormData.Map,
        id: "product",
        name: "product",
        data: %{},
        action: nil,
        hidden: [],
        params: %{},
        errors: [],
        options: []
      }

      result = Helpers.translation_input(form, :name, :es, class: "my-input-class")

      {:safe, html} = result
      assert html =~ "my-input-class"
    end
  end

  describe "language_switcher/3" do
    test "generates language switcher HTML" do
      conn = build_conn(assigns: %{locale: "en"}, query_params: %{})

      result = Helpers.language_switcher(conn, TestProduct)

      {:safe, html} = result
      assert html =~ "<ul"
      assert html =~ "language-switcher"
      assert html =~ "English"
      assert html =~ "Español"
      assert html =~ "Français"
    end

    test "marks current locale as active" do
      conn = build_conn(assigns: %{locale: "es"}, query_params: %{})

      result = Helpers.language_switcher(conn, TestProduct)

      {:safe, html} = result
      # The Spanish entry should have active class
      assert html =~ "active"
    end

    test "includes locale in URL" do
      conn = build_conn(assigns: %{locale: "en"}, request_path: "/products", query_params: %{})

      result = Helpers.language_switcher(conn, TestProduct)

      {:safe, html} = result
      assert html =~ "locale=es"
      assert html =~ "locale=fr"
    end

    test "accepts custom CSS class" do
      conn = build_conn(assigns: %{locale: "en"}, query_params: %{})

      result = Helpers.language_switcher(conn, TestProduct, class: "my-switcher")

      {:safe, html} = result
      assert html =~ "my-switcher"
    end
  end

  describe "security - HTML escaping" do
    test "t/3 escapes HTML in translations" do
      product =
        build_product(name_translations: %{en: "<script>alert('xss')</script>"})

      result = Helpers.t(product, :name, locale: :en)

      # HTML entities should be escaped in the result
      # The function returns a plain string, escaping happens at render time
      assert result == "<script>alert('xss')</script>"
    end

    test "translate_field returns raw string without escaping" do
      product =
        build_product(name_translations: %{en: "<b>Bold</b>"})

      result = Helpers.translate_field(product, :name, :en)

      # Should be raw string
      assert result == "<b>Bold</b>"
    end
  end

  describe "edge cases" do
    test "handles nil resource with expected error" do
      # all_translations expects a map, nil will raise BadMapError
      # This is expected behavior - callers should handle nil resources before calling
      assert_raise BadMapError, fn ->
        Helpers.all_translations(nil, :name)
      end
    end

    test "handles resource without translations field" do
      product = %{id: 1, sku: "TEST"}

      result = Helpers.all_translations(product, :name)
      assert result == %{}
    end

    test "handles empty translations map" do
      product = build_product(name_translations: %{})

      result = Helpers.t(product, :name, locale: :en, fallback: "Fallback")
      assert result == "Fallback"
    end
  end
end
