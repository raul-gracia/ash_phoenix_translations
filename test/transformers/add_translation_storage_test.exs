defmodule AshPhoenixTranslations.Transformers.AddTranslationStorageTest do
  use ExUnit.Case

  describe "Database Backend" do
    defmodule DatabaseProduct do
      use Ash.Resource,
        domain: AshPhoenixTranslations.Transformers.AddTranslationStorageTest.Domain,
        data_layer: Ash.DataLayer.Ets,
        extensions: [AshPhoenixTranslations]

      ets do
        table :test_database_products
      end

      translations do
        translatable_attribute :name, :string do
          locales [:en, :es, :fr]
          required [:en]
          validation(max_length: 100)
        end

        translatable_attribute :description, :text do
          locales [:en, :es]
          fallback(:en)
        end

        backend :database
      end

      actions do
        defaults [:create, :read, :update, :destroy]
      end

      attributes do
        uuid_primary_key :id
        timestamps()
      end
    end

    test "adds map storage attributes for database backend" do
      resource_info = Ash.Resource.Info
      attributes = resource_info.attribute_names(DatabaseProduct)

      # Should have translation storage fields
      assert :name_translations in attributes
      assert :description_translations in attributes

      # Check the storage attribute details
      name_attr = resource_info.attribute(DatabaseProduct, :name_translations)
      assert name_attr.type == Ash.Type.Map
      # Storage attributes must be public for update_translation action
      assert name_attr.public? == true
      assert name_attr.default == %{}

      # Check constraints are properly set
      assert name_attr.constraints[:fields][:en]
      assert name_attr.constraints[:fields][:es]
      assert name_attr.constraints[:fields][:fr]
    end

    test "storage attributes are public for update_translation action" do
      resource_info = Ash.Resource.Info

      public_attrs =
        DatabaseProduct
        |> resource_info.attributes()
        |> Enum.filter(& &1.public?)
        |> Enum.map(& &1.name)

      # Storage attributes must be public for update_translation action to work
      assert :name_translations in public_attrs
      assert :description_translations in public_attrs
    end
  end

  describe "Gettext Backend" do
    defmodule GettextProduct do
      use Ash.Resource,
        domain: AshPhoenixTranslations.Transformers.AddTranslationStorageTest.Domain,
        data_layer: Ash.DataLayer.Ets,
        extensions: [AshPhoenixTranslations]

      ets do
        table :test_gettext_products
      end

      translations do
        translatable_attribute :name, :string do
          locales [:en, :es, :fr]
        end

        backend :gettext
      end

      actions do
        defaults [:create, :read, :update, :destroy]
      end

      attributes do
        uuid_primary_key :id
        timestamps()
      end
    end

    test "does not add storage attributes for gettext backend" do
      resource_info = Ash.Resource.Info
      attributes = resource_info.attribute_names(GettextProduct)

      # Should NOT have translation storage fields for gettext
      refute :name_translations in attributes
      refute :name_gettext_key in attributes
    end
  end

  # Test domain
  defmodule Domain do
    use Ash.Domain,
      validate_config_inclusion?: false

    resources do
      resource AshPhoenixTranslations.Transformers.AddTranslationStorageTest.DatabaseProduct
      resource AshPhoenixTranslations.Transformers.AddTranslationStorageTest.GettextProduct
    end
  end
end
