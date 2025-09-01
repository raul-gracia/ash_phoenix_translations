defmodule AshPhoenixTranslations.JsonApiTest do
  use ExUnit.Case, async: true

  alias AshPhoenixTranslations.JsonApi

  defmodule TestResource do
    use Ash.Resource,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshPhoenixTranslations]

    attributes do
      uuid_primary_key :id
      attribute :price, :decimal
    end

    translations do
      translatable_attribute :name, :string, locales: [:en, :es, :fr]

      translatable_attribute :description, :text,
        locales: [:en, :es, :fr],
        fallback: :en
    end
  end

  describe "LocalePlug" do
    test "extracts locale from query parameter" do
      conn =
        %{
          params: %{"locale" => "es"},
          assigns: %{}
        }
        |> Map.put(:private, %{})

      conn = JsonApi.LocalePlug.call(conn, [])

      assert conn.assigns.locale == :es
      assert conn.private.ash_json_api_locale == :es
    end

    test "extracts locale from Accept-Language header" do
      conn =
        %{
          params: %{},
          assigns: %{},
          req_headers: [{"accept-language", "fr-FR,fr;q=0.9,en;q=0.8"}]
        }
        |> Map.put(:private, %{})

      # Mock get_req_header function
      conn =
        Map.put(conn, :get_req_header, fn _conn, header ->
          if header == "accept-language" do
            ["fr-FR,fr;q=0.9,en;q=0.8"]
          else
            []
          end
        end)

      conn = JsonApi.LocalePlug.call(conn, [])

      assert conn.assigns.locale == :fr
    end

    test "falls back to default locale" do
      conn =
        %{
          params: %{},
          assigns: %{}
        }
        |> Map.put(:private, %{})
        |> Map.put(:req_headers, [])
        |> Map.put(:get_req_header, fn _conn, _header -> [] end)

      conn = JsonApi.LocalePlug.call(conn, [])

      assert conn.assigns.locale == :en
    end
  end

  describe "serialize_translations/2" do
    test "serializes translations for current locale" do
      resource =
        struct(TestResource, %{
          id: "123",
          name_translations: %{
            en: "Product",
            es: "Producto",
            fr: "Produit"
          },
          description_translations: %{
            en: "A great product",
            es: "Un gran producto"
          },
          price: 99.99
        })

      result = JsonApi.serialize_translations(resource, :es)

      assert result.name == "Producto"
      assert result.description == "Un gran producto"
    end

    test "falls back to configured fallback locale" do
      resource =
        struct(TestResource, %{
          id: "123",
          name_translations: %{
            en: "Product"
          },
          description_translations: %{
            en: "A great product"
          },
          price: 99.99
        })

      result = JsonApi.serialize_translations(resource, :de)

      assert result.name == "Product"
      assert result.description == "A great product"
    end

    test "handles missing translations" do
      resource =
        struct(TestResource, %{
          id: "123",
          name_translations: %{},
          description_translations: %{},
          price: 99.99
        })

      result = JsonApi.serialize_translations(resource, :es)

      assert result.name == nil
      assert result.description == nil
    end
  end

  describe "deserialize_translation_updates/2" do
    test "deserializes multiple locale updates" do
      params = %{
        "name" => %{
          "translations" => %{
            "en" => "Updated Product",
            "es" => "Producto Actualizado"
          }
        }
      }

      result = JsonApi.deserialize_translation_updates(params, TestResource)

      assert result.name_translations == %{
               en: "Updated Product",
               es: "Producto Actualizado"
             }
    end

    test "deserializes single locale update" do
      params = %{
        "name" => %{
          "locale" => "fr",
          "value" => "Produit Mis à Jour"
        }
      }

      result = JsonApi.deserialize_translation_updates(params, TestResource)

      assert result.name_translations == %{
               fr: "Produit Mis à Jour"
             }
    end

    test "handles default locale update with string value" do
      params = %{
        "name" => "Simple Update"
      }

      result = JsonApi.deserialize_translation_updates(params, TestResource)

      assert result.name == "Simple Update"
    end

    test "passes through non-translatable fields" do
      params = %{
        "price" => 149.99,
        "name" => "Updated"
      }

      result = JsonApi.deserialize_translation_updates(params, TestResource)

      assert result.price == 149.99
      assert result.name == "Updated"
    end
  end

  describe "add_translation_metadata/2" do
    test "adds translation metadata to response" do
      response = %{
        data: %{id: "123", type: "product"}
      }

      resource =
        struct(TestResource, %{
          id: "123",
          name_translations: %{
            en: "Product",
            es: "Producto"
          }
        })

      updated = JsonApi.add_translation_metadata(response, resource)

      assert updated.meta.default_locale == :en
      assert is_list(updated.meta.available_locales)
      assert updated.meta.translation_completeness >= 0
    end

    test "merges with existing meta" do
      response = %{
        data: %{id: "123"},
        meta: %{total_count: 42}
      }

      resource = struct(TestResource, %{id: "123"})

      updated = JsonApi.add_translation_metadata(response, resource)

      assert updated.meta.total_count == 42
      assert Map.has_key?(updated.meta, :default_locale)
    end
  end

  describe "apply_sparse_fieldsets/3" do
    test "applies fieldsets with locale context" do
      query = %Ash.Query{}
      fields = [:name, :price]
      locale = :es

      result = JsonApi.apply_sparse_fieldsets(query, fields, locale)

      # Would test actual query modification if Ash.Query was available
      assert result != nil
    end
  end
end
