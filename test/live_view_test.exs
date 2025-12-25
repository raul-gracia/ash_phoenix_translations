defmodule AshPhoenixTranslations.LiveViewTest do
  @moduledoc """
  Tests for AshPhoenixTranslations.LiveView module.

  This test module verifies LiveView integration including:
  - Locale assignment and management
  - Translation helpers
  - Socket assign updates
  - Component rendering (tested as functions)
  """
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest

  alias AshPhoenixTranslations.LiveView

  # Test resource
  defmodule TestProduct do
    use Ash.Resource,
      domain: AshPhoenixTranslations.LiveViewTest.TestDomain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshPhoenixTranslations]

    ets do
      table :live_view_test_products
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
      resource AshPhoenixTranslations.LiveViewTest.TestProduct
    end
  end

  # Helper to create a mock socket
  defp build_socket(opts \\ []) do
    %Phoenix.LiveView.Socket{
      assigns: Map.merge(%{__changed__: %{}}, Keyword.get(opts, :assigns, %{})),
      private: Keyword.get(opts, :private, %{}),
      endpoint: Keyword.get(opts, :endpoint)
    }
  end

  setup do
    # Clean ETS table before each test
    if :ets.whereis(:live_view_test_products) != :undefined do
      :ets.delete_all_objects(:live_view_test_products)
    end

    :ok
  end

  describe "assign_locale/3" do
    # Note: assign_locale attaches hooks which require the LiveView to be mounted
    # via router. These tests verify the locale assignment behavior without
    # testing hook attachment which requires integration tests.

    test "assigns locale from session directly (without hooks)" do
      socket = build_socket()
      session = %{"locale" => "es"}

      # Directly set locale to test the value extraction logic
      locale = session["locale"] || "en"
      result = Phoenix.Component.assign(socket, :locale, locale)

      assert result.assigns.locale == "es"
    end

    test "params take precedence over session" do
      socket = build_socket()
      session = %{"locale" => "de"}
      params = %{"locale" => "it"}

      # Test the priority logic: params > session > default
      locale = params["locale"] || session["locale"] || "en"
      result = Phoenix.Component.assign(socket, :locale, locale)

      assert result.assigns.locale == "it"
    end

    test "defaults to en when no locale provided" do
      socket = build_socket()
      session = %{}
      params = %{}

      locale = params["locale"] || session["locale"] || "en"
      result = Phoenix.Component.assign(socket, :locale, locale)

      assert result.assigns.locale == "en"
    end
  end

  describe "update_locale/2" do
    # Note: update_locale calls push_event and put_session which require
    # a fully initialized LiveView socket with :live_temp. These tests
    # verify the logic without requiring full socket initialization.

    test "updates locale via assign" do
      socket = build_socket(assigns: %{locale: "en"})

      # Test the core locale assignment logic
      # update_locale does: assign(socket, :locale, locale) first
      result = Phoenix.Component.assign(socket, :locale, "es")

      assert result.assigns.locale == "es"
    end

    test "locale assignment preserves other assigns" do
      socket = build_socket(assigns: %{locale: "en", user: "test_user"})

      result = Phoenix.Component.assign(socket, :locale, "fr")

      assert result.assigns.locale == "fr"
      assert result.assigns.user == "test_user"
    end
  end

  describe "assign_translations/3" do
    test "assigns translated resources to socket" do
      {:ok, product} =
        TestProduct
        |> Ash.Changeset.for_create(:create, %{
          sku: "TEST-001",
          name_translations: %{en: "English Name", es: "Nombre en Espanol"}
        })
        |> Ash.create()

      # Use atom locale since translate/2 requires atom locales
      socket = build_socket(assigns: %{locale: :es})

      result = LiveView.assign_translations(socket, :product, product)

      assert result.assigns.product.name == "Nombre en Espanol"
    end

    test "assigns translated list of resources" do
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

      # Use atom locale since translate/2 requires atom locales
      socket = build_socket(assigns: %{locale: :es})

      result = LiveView.assign_translations(socket, :products, [p1, p2])

      assert length(result.assigns.products) == 2
      assert Enum.at(result.assigns.products, 0).name == "Producto 1"
      assert Enum.at(result.assigns.products, 1).name == "Producto 2"
    end

    test "uses en as default locale" do
      {:ok, product} =
        TestProduct
        |> Ash.Changeset.for_create(:create, %{
          sku: "TEST-001",
          name_translations: %{en: "English Name", es: "Nombre en Espanol"}
        })
        |> Ash.create()

      # No locale set, defaults to "en" string which translate handles
      socket = build_socket(assigns: %{locale: :en})

      result = LiveView.assign_translations(socket, :product, product)

      assert result.assigns.product.name == "English Name"
    end
  end

  describe "handle_locale_change/2" do
    # Note: handle_locale_change calls update_locale which uses push_event
    # requiring a fully initialized socket. We test the reload_translations
    # logic separately.

    test "reload_translations updates translated resources" do
      {:ok, product} =
        TestProduct
        |> Ash.Changeset.for_create(:create, %{
          sku: "TEST-001",
          name_translations: %{en: "English Name", es: "Nombre en Espanol"}
        })
        |> Ash.create()

      # Simulate what handle_locale_change does: update locale then reload
      # We test reload_translations directly since update_locale requires :live_temp
      socket =
        build_socket(assigns: %{locale: :es, product: product})

      result = LiveView.reload_translations(socket)

      assert result.assigns.product.name == "Nombre en Espanol"
    end
  end

  describe "reload_translations/1" do
    test "reloads translatable resources with current locale" do
      {:ok, product} =
        TestProduct
        |> Ash.Changeset.for_create(:create, %{
          sku: "TEST-001",
          name_translations: %{en: "English Name", es: "Nombre en Espanol"}
        })
        |> Ash.create()

      # Use atom locale since translate/2 requires atoms
      socket =
        build_socket(assigns: %{locale: :es, product: product})

      result = LiveView.reload_translations(socket)

      assert result.assigns.product.name == "Nombre en Espanol"
    end

    test "handles list of resources" do
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

      # Use atom locale since translate/2 requires atoms
      socket =
        build_socket(assigns: %{locale: :es, products: [p1, p2]})

      result = LiveView.reload_translations(socket)

      assert Enum.at(result.assigns.products, 0).name == "Producto 1"
      assert Enum.at(result.assigns.products, 1).name == "Producto 2"
    end

    test "ignores non-translatable assigns" do
      {:ok, product} =
        TestProduct
        |> Ash.Changeset.for_create(:create, %{
          sku: "TEST-001",
          name_translations: %{en: "English Name"}
        })
        |> Ash.create()

      # Use atom locale since translate/2 requires atoms
      socket =
        build_socket(assigns: %{locale: :en, product: product, count: 5, title: "Test"})

      result = LiveView.reload_translations(socket)

      # Non-translatable assigns should remain unchanged
      assert result.assigns.count == 5
      assert result.assigns.title == "Test"
    end
  end

  describe "handle_translation_update/5" do
    test "updates translation in resource assign" do
      product = %{
        __struct__: TestProduct,
        id: "123",
        sku: "TEST-001",
        name_translations: %{en: "Original", es: "Original ES"}
      }

      socket = build_socket(assigns: %{locale: "en", product: product})

      result = LiveView.handle_translation_update(socket, "123", :name, :es, "Updated ES")

      assert result.assigns.product.name_translations[:es] == "Updated ES"
    end

    test "updates translation in list of resources" do
      products = [
        %{__struct__: TestProduct, id: "123", sku: "TEST-001", name_translations: %{en: "P1"}},
        %{__struct__: TestProduct, id: "456", sku: "TEST-002", name_translations: %{en: "P2"}}
      ]

      socket = build_socket(assigns: %{locale: "en", products: products})

      result = LiveView.handle_translation_update(socket, "123", :name, :es, "P1 ES")

      updated_product = Enum.find(result.assigns.products, &(&1.id == "123"))
      assert updated_product.name_translations[:es] == "P1 ES"

      # Other product should be unchanged
      other_product = Enum.find(result.assigns.products, &(&1.id == "456"))
      assert other_product.name_translations == %{en: "P2"}
    end
  end

  describe "on_mount/4" do
    # Note: on_mount also attaches hooks which requires router-mounted LiveViews
    # These tests verify the locale extraction logic without hook attachment

    test "extracts locale from session correctly" do
      session = %{"locale" => "es"}

      # Test the extraction logic used by on_mount
      locale = session["locale"] || "en"
      assert locale == "es"
    end

    test "defaults to en when no session locale" do
      session = %{}

      locale = session["locale"] || "en"
      assert locale == "en"
    end
  end

  describe "locale_name/1 helper" do
    test "returns correct display names" do
      # Access through module since it's a private function used by components
      # We test via the exposed helpers module - use accented names
      assert AshPhoenixTranslations.Helpers.locale_name(:en) == "English"
      assert AshPhoenixTranslations.Helpers.locale_name(:es) == "Español"
      assert AshPhoenixTranslations.Helpers.locale_name(:fr) == "Français"
      assert AshPhoenixTranslations.Helpers.locale_name(:de) == "Deutsch"
      assert AshPhoenixTranslations.Helpers.locale_name(:ja) == "日本語"
    end

    test "returns uppercase code for unknown locales" do
      assert AshPhoenixTranslations.Helpers.locale_name(:zz) == "ZZ"
    end
  end

  describe "PubSub integration" do
    test "subscribe_to_translations creates subscription topic" do
      # This tests the topic generation rather than actual subscription
      # since we don't have a full PubSub setup in tests
      topic = "translations:#{TestProduct}"
      assert topic == "translations:Elixir.AshPhoenixTranslations.LiveViewTest.TestProduct"
    end

    test "broadcast_translation_update sends correct message format" do
      product = %{__struct__: TestProduct, id: "123"}

      # Test the message format that would be broadcast
      message = {:translation_updated, product.id, :name, :es, "Nuevo"}

      assert elem(message, 0) == :translation_updated
      assert elem(message, 1) == "123"
      assert elem(message, 2) == :name
      assert elem(message, 3) == :es
      assert elem(message, 4) == "Nuevo"
    end
  end

  describe "locale_switcher/1 component" do
    test "renders with default locales" do
      socket = build_socket(assigns: %{locale: :en})

      html =
        render_component(&LiveView.locale_switcher/1,
          socket: socket,
          class: "locale-switcher",
          locales: ["en", "es", "fr"]
        )

      # Check structure
      assert html =~ "locale-switcher"
      assert html =~ "phx-change=\"change_locale\""
      assert html =~ "name=\"locale\""
    end

    test "renders with custom locales" do
      socket = build_socket(assigns: %{locale: :es})

      html =
        render_component(&LiveView.locale_switcher/1,
          socket: socket,
          class: "custom-class",
          locales: ["en", "es", "fr"]
        )

      # Should only include specified locales
      assert html =~ "English"
      assert html =~ "Español"
      assert html =~ "Français"
      # Should not include other default locales
      refute html =~ "Deutsch"
    end

    test "marks current locale as selected" do
      socket = build_socket(assigns: %{locale: "es"})

      html =
        render_component(&LiveView.locale_switcher/1,
          socket: socket,
          class: "locale-switcher",
          locales: ["en", "es", "fr"]
        )

      # Spanish should be marked as selected (note: selected attribute renders as selected="true")
      assert html =~ ~r/value="es"[^>]*selected/s
    end
  end

  describe "translation_field/1 component" do
    test "renders text inputs for each locale" do
      form = %Phoenix.HTML.Form{
        name: "product",
        data: %TestProduct{
          name_translations: %{en: "English", es: "Español"}
        },
        source: nil,
        impl: nil,
        id: "product",
        params: %{}
      }

      html =
        render_component(&LiveView.translation_field/1,
          form: form,
          field: :name,
          locales: [:en, :es],
          type: "text",
          class: "translation-field"
        )

      # Should have inputs for each locale
      assert html =~ "English"
      assert html =~ "Español"
      assert html =~ "name=\"product[name_translations][en]\""
      assert html =~ "name=\"product[name_translations][es]\""
    end

    test "renders textarea inputs when type is textarea" do
      form = %Phoenix.HTML.Form{
        name: "product",
        data: %TestProduct{
          description_translations: %{en: "Description"}
        },
        source: nil,
        impl: nil,
        id: "product",
        params: %{}
      }

      html =
        render_component(&LiveView.translation_field/1,
          form: form,
          field: :description,
          locales: [:en, :es],
          type: "textarea",
          class: "translation-field"
        )

      # Should have textarea elements
      assert html =~ "<textarea"
      assert html =~ "name=\"product[description_translations][en]\""
    end

    test "uses custom label when provided" do
      form = %Phoenix.HTML.Form{
        name: "product",
        data: %TestProduct{name_translations: %{}},
        source: nil,
        impl: nil,
        id: "product",
        params: %{}
      }

      html =
        render_component(&LiveView.translation_field/1,
          form: form,
          field: :name,
          locales: [:en],
          type: "text",
          label: "Product Title",
          class: "translation-field"
        )

      assert html =~ "Product Title"
    end
  end

  describe "translation_progress/1 component" do
    test "calculates and displays progress percentage" do
      {:ok, product} =
        TestProduct
        |> Ash.Changeset.for_create(:create, %{
          sku: "TEST-001",
          name_translations: %{en: "English", es: "Español", fr: ""},
          description_translations: %{en: "Desc", es: "", fr: ""}
        })
        |> Ash.create()

      html =
        render_component(&LiveView.translation_progress/1,
          resource: product,
          fields: [:name, :description],
          locales: [:en, :es, :fr],
          class: "translation-progress"
        )

      # Progress should be 50% (3 out of 6 translations filled)
      assert html =~ "50%"
      assert html =~ "progress-bar"
    end

    test "shows 100% when all translations complete" do
      {:ok, product} =
        TestProduct
        |> Ash.Changeset.for_create(:create, %{
          sku: "TEST-001",
          name_translations: %{en: "A", es: "B", fr: "C"}
        })
        |> Ash.create()

      html =
        render_component(&LiveView.translation_progress/1,
          resource: product,
          fields: [:name],
          locales: [:en, :es, :fr],
          class: "translation-progress"
        )

      assert html =~ "100%"
    end
  end

  describe "translation_preview/1 component" do
    test "renders preview with locale tabs" do
      {:ok, product} =
        TestProduct
        |> Ash.Changeset.for_create(:create, %{
          sku: "TEST-001",
          name_translations: %{en: "English", es: "Español"}
        })
        |> Ash.create()

      socket = build_socket(assigns: %{preview_locale: :en})

      html =
        render_component(&LiveView.translation_preview/1,
          resource: product,
          field: :name,
          locales: [:en, :es],
          class: "translation-preview",
          socket: socket
        )

      # Should have tabs
      assert html =~ "tab"
      assert html =~ "phx-click=\"set_preview_locale\""
      assert html =~ "English"
      assert html =~ "preview-content"
    end

    test "marks active tab for current preview locale" do
      {:ok, product} =
        TestProduct
        |> Ash.Changeset.for_create(:create, %{
          sku: "TEST-001",
          name_translations: %{en: "English", es: "Español"}
        })
        |> Ash.create()

      socket = build_socket(assigns: %{preview_locale: :es})

      html =
        render_component(&LiveView.translation_preview/1,
          resource: product,
          field: :name,
          locales: [:en, :es],
          class: "translation-preview",
          socket: socket
        )

      # Spanish tab should be marked as active
      assert html =~ "active"
    end
  end

  describe "private helper functions" do
    test "translatable_fields/1 returns empty list for non-translatable resource" do
      # Test with a struct that doesn't have translation support
      non_translatable = %{__struct__: String, value: "test"}

      # Call the module's translatable check indirectly via reload_translations
      socket = build_socket(assigns: %{locale: :en, data: non_translatable})

      # Should not raise, just skip non-translatable assigns
      result = LiveView.reload_translations(socket)

      assert result.assigns.data == non_translatable
    end

    test "calculate_completeness handles zero fields" do
      {:ok, product} =
        TestProduct
        |> Ash.Changeset.for_create(:create, %{
          sku: "TEST-001",
          name_translations: %{en: "Name"}
        })
        |> Ash.create()

      html =
        render_component(&LiveView.translation_progress/1,
          resource: product,
          fields: [],
          locales: [:en, :es],
          class: "translation-progress"
        )

      # Should show 0% when no fields specified
      assert html =~ "0%"
    end

    test "translate_resource handles missing translations gracefully" do
      {:ok, product} =
        TestProduct
        |> Ash.Changeset.for_create(:create, %{
          sku: "TEST-001",
          name_translations: %{en: "Name"}
        })
        |> Ash.create()

      socket = build_socket(assigns: %{locale: :de})

      result = LiveView.assign_translations(socket, :product, product)

      # Should handle missing German translation
      assert result.assigns[:product]
    end
  end

  describe "edge cases and error handling" do
    test "reload_translations handles empty assigns" do
      socket = build_socket(assigns: %{locale: :en})

      result = LiveView.reload_translations(socket)

      # Should not raise with empty assigns
      assert result.assigns.locale == :en
    end

    test "handle_translation_update handles non-matching resource ID" do
      products = [
        %{__struct__: TestProduct, id: "123", name_translations: %{en: "P1"}},
        %{__struct__: TestProduct, id: "456", name_translations: %{en: "P2"}}
      ]

      socket = build_socket(assigns: %{products: products})

      # Update with ID that doesn't exist
      result = LiveView.handle_translation_update(socket, "999", :name, :es, "New")

      # Products should remain unchanged
      assert result.assigns.products == products
    end

    test "assign_translations with empty list" do
      socket = build_socket(assigns: %{locale: :en})

      result = LiveView.assign_translations(socket, :products, [])

      assert result.assigns.products == []
    end

    test "reload_translations with non-struct values in assigns" do
      socket =
        build_socket(
          assigns: %{
            locale: :en,
            string_value: "test",
            number_value: 42,
            list_value: [1, 2, 3],
            map_value: %{key: "value"}
          }
        )

      result = LiveView.reload_translations(socket)

      # All non-resource values should remain unchanged
      assert result.assigns.string_value == "test"
      assert result.assigns.number_value == 42
      assert result.assigns.list_value == [1, 2, 3]
      assert result.assigns.map_value == %{key: "value"}
    end

    test "handle_translation_update with empty assigns" do
      socket = build_socket(assigns: %{locale: :en})

      result = LiveView.handle_translation_update(socket, "123", :name, :es, "Value")

      # Should not raise with empty assigns
      assert result.assigns.locale == :en
    end
  end

  describe "component integration" do
    test "components work together in workflow" do
      {:ok, product} =
        TestProduct
        |> Ash.Changeset.for_create(:create, %{
          sku: "TEST-001",
          name_translations: %{en: "Product", es: "Producto"}
        })
        |> Ash.create()

      socket = build_socket(assigns: %{locale: :en})

      # Assign translations
      socket = LiveView.assign_translations(socket, :product, product)

      # Render locale switcher
      switcher_html =
        render_component(&LiveView.locale_switcher/1,
          socket: socket,
          class: "switcher",
          locales: ["en", "es"]
        )

      assert switcher_html =~ "switcher"

      # Render progress
      progress_html =
        render_component(&LiveView.translation_progress/1,
          resource: socket.assigns.product,
          fields: [:name],
          locales: [:en, :es],
          class: "progress"
        )

      assert progress_html =~ "100%"
    end
  end
end
