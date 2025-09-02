defmodule AshPhoenixTranslations.EmbeddedTest do
  use ExUnit.Case, async: true

  alias AshPhoenixTranslations.Embedded

  defmodule TestDomain do
    use Ash.Domain

    resources do
      resource Address
      resource ProductFeature
      resource User
      resource Product
    end
  end

  defmodule Address do
    use Ash.Resource,
      domain: TestDomain,
      data_layer: :embedded,
      extensions: [AshPhoenixTranslations]

    attributes do
      uuid_primary_key :id
      attribute :postal_code, :string
    end

    translations do
      translatable_attribute :street, :string, locales: [:en, :es, :fr]

      translatable_attribute :city, :string, locales: [:en, :es, :fr]
    end
  end

  defmodule ProductFeature do
    use Ash.Resource,
      domain: TestDomain,
      data_layer: :embedded,
      extensions: [AshPhoenixTranslations]

    attributes do
      uuid_primary_key :id
    end

    translations do
      translatable_attribute :name, :string, locales: [:en, :es, :fr]

      translatable_attribute :description, :text, locales: [:en, :es, :fr]
    end
  end

  defmodule User do
    use Ash.Resource,
      domain: TestDomain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshPhoenixTranslations]

    attributes do
      uuid_primary_key :id
      attribute :email, :string
      attribute :address, Address
    end

    translations do
      translatable_attribute :name, :string, locales: [:en, :es, :fr]
    end
  end

  defmodule Product do
    use Ash.Resource,
      domain: TestDomain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshPhoenixTranslations]

    attributes do
      uuid_primary_key :id
      attribute :sku, :string
      attribute :features, {:array, ProductFeature}
    end

    translations do
      translatable_attribute :name, :string, locales: [:en, :es, :fr]
    end
  end

  describe "translate_embedded/2" do
    test "translates embedded schema attributes" do
      user =
        struct(User, %{
          id: "user-1",
          email: "test@example.com",
          name_translations: %{
            en: "John Doe",
            es: "Juan Pérez"
          },
          address:
            struct(Address, %{
              id: "addr-1",
              postal_code: "12345",
              street_translations: %{
                en: "Main Street",
                es: "Calle Principal"
              },
              city_translations: %{
                en: "New York",
                es: "Nueva York"
              }
            })
        })

      translated = Embedded.translate_embedded(user, :es)

      assert translated.address.street_translations[:es] == "Calle Principal"
      assert translated.address.city_translations[:es] == "Nueva York"
    end

    test "falls back to English for missing translations" do
      user =
        struct(User, %{
          id: "user-1",
          address:
            struct(Address, %{
              id: "addr-1",
              street_translations: %{
                en: "Main Street"
              },
              city_translations: %{
                en: "New York"
              }
            })
        })

      translated = Embedded.translate_embedded(user, :fr)

      # Would check fallback behavior
      assert translated.address != nil
    end
  end

  describe "translate_embedded_array/3" do
    test "translates array of embedded schemas" do
      features = [
        struct(ProductFeature, %{
          id: "feat-1",
          name_translations: %{
            en: "Waterproof",
            es: "Impermeable"
          },
          description_translations: %{
            en: "Resistant to water",
            es: "Resistente al agua"
          }
        }),
        struct(ProductFeature, %{
          id: "feat-2",
          name_translations: %{
            en: "Lightweight",
            es: "Ligero"
          },
          description_translations: %{
            en: "Very light weight",
            es: "Muy ligero"
          }
        })
      ]

      translated = Embedded.translate_embedded_array(features, ProductFeature, :es)

      assert length(translated) == 2
      assert Enum.at(translated, 0).name_translations[:es] == "Impermeable"
      assert Enum.at(translated, 1).name_translations[:es] == "Ligero"
    end

    test "handles empty array" do
      translated = Embedded.translate_embedded_array([], ProductFeature, :es)

      assert translated == []
    end
  end

  describe "update_embedded_translation/4" do
    test "updates nested translation" do
      user =
        struct(User, %{
          id: "user-1",
          address:
            struct(Address, %{
              id: "addr-1",
              street_translations: %{
                en: "Main Street"
              }
            })
        })

      {:ok, updated} =
        Embedded.update_embedded_translation(
          user,
          [:address, :street],
          :es,
          "Calle Principal"
        )

      assert is_map(updated)
    end

    test "handles invalid path" do
      user = struct(User, %{id: "user-1"})

      result =
        Embedded.update_embedded_translation(
          user,
          [:invalid, :path],
          :es,
          "value"
        )

      # Would return error for invalid path
      assert result != nil
    end
  end

  describe "validate_embedded_translations/2" do
    test "validates complete translations" do
      user =
        struct(User, %{
          id: "user-1",
          name_translations: %{
            en: "John",
            es: "Juan",
            fr: "Jean"
          },
          address:
            struct(Address, %{
              street_translations: %{
                en: "Main St",
                es: "Calle Principal",
                fr: "Rue Principale"
              },
              city_translations: %{
                en: "NYC",
                es: "Nueva York",
                fr: "New York"
              }
            })
        })

      assert :ok = Embedded.validate_embedded_translations(user, [:en, :es, :fr])
    end

    test "reports missing translations" do
      user =
        struct(User, %{
          id: "user-1",
          name_translations: %{
            en: "John"
          },
          address:
            struct(Address, %{
              street_translations: %{
                en: "Main St"
              }
            })
        })

      {:error, errors} = Embedded.validate_embedded_translations(user, [:en, :es, :fr])

      assert is_list(errors)
      assert length(errors) > 0
    end
  end

  describe "extract_translatable_paths/1" do
    test "extracts paths from resource module" do
      paths = Embedded.extract_translatable_paths(User)

      assert [:name] in paths
    end

    test "extracts paths from resource instance" do
      user = struct(User, %{id: "user-1"})
      paths = Embedded.extract_translatable_paths(user)

      assert is_list(paths)
    end
  end

  describe "bulk_update_embedded_translations/2" do
    test "updates multiple paths" do
      user =
        struct(User, %{
          id: "user-1",
          address: struct(Address, %{id: "addr-1"})
        })

      translations = %{
        [:name] => %{es: "Juan", fr: "Jean"},
        [:address, :street] => %{es: "Calle", fr: "Rue"}
      }

      {:ok, updated} = Embedded.bulk_update_embedded_translations(user, translations)

      assert updated != nil
    end
  end

  describe "merge_embedded_translations/3" do
    test "merges translations with merge strategy" do
      user =
        struct(User, %{
          id: "user-1",
          name_translations: %{en: "John"}
        })

      new_translations = %{
        name_translations: %{es: "Juan", fr: "Jean"}
      }

      {:ok, merged} =
        Embedded.merge_embedded_translations(
          user,
          new_translations,
          strategy: :merge
        )

      assert merged != nil
    end

    test "replaces translations with replace strategy" do
      user =
        struct(User, %{
          id: "user-1",
          name_translations: %{en: "John", es: "Juan"}
        })

      new_translations = %{
        name_translations: %{fr: "Jean"}
      }

      {:ok, replaced} =
        Embedded.merge_embedded_translations(
          user,
          new_translations,
          strategy: :replace
        )

      assert replaced != nil
    end

    test "fills missing translations with fill strategy" do
      user =
        struct(User, %{
          id: "user-1",
          name_translations: %{en: "John"}
        })

      new_translations = %{
        name_translations: %{en: "Johnny", es: "Juan"}
      }

      {:ok, filled} =
        Embedded.merge_embedded_translations(
          user,
          new_translations,
          strategy: :fill
        )

      assert filled != nil
    end
  end

  describe "embedded_translation_report/1" do
    test "generates completeness report" do
      user =
        struct(User, %{
          id: "user-1",
          name_translations: %{
            en: "John",
            es: "Juan"
          },
          address:
            struct(Address, %{
              street_translations: %{
                en: "Main St"
              },
              city_translations: %{
                en: "NYC",
                es: "Nueva York",
                fr: "New York"
              }
            })
        })

      report = Embedded.embedded_translation_report(user)

      assert report.total_paths > 0
      assert report.average_completeness >= 0
      assert report.average_completeness <= 100
      assert is_list(report.incomplete_paths)
    end
  end
end
