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
      attributes = Ash.Resource.Info.attribute_names(DatabaseProduct)

      # Should have translation storage fields
      assert :name_translations in attributes
      assert :description_translations in attributes

      # Check the storage attribute details
      name_attr = Ash.Resource.Info.attribute(DatabaseProduct, :name_translations)
      assert name_attr.type == Ash.Type.Map
      assert name_attr.public? == false
      assert name_attr.default == %{}

      # Check constraints are properly set
      assert name_attr.constraints[:fields][:en]
      assert name_attr.constraints[:fields][:es]
      assert name_attr.constraints[:fields][:fr]
    end

    test "storage attributes are not public" do
      public_attrs =
        DatabaseProduct
        |> Ash.Resource.Info.attributes()
        |> Enum.filter(& &1.public?)
        |> Enum.map(& &1.name)

      refute :name_translations in public_attrs
      refute :description_translations in public_attrs
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
      attributes = Ash.Resource.Info.attribute_names(GettextProduct)

      # Should NOT have translation storage fields for gettext
      refute :name_translations in attributes
      refute :name_gettext_key in attributes
    end
  end

  describe "Redis Backend" do
    defmodule RedisProduct do
      use Ash.Resource,
        domain: AshPhoenixTranslations.Transformers.AddTranslationStorageTest.Domain,
        data_layer: Ash.DataLayer.Ets,
        extensions: [AshPhoenixTranslations]

      ets do
        table :test_redis_products
      end

      translations do
        translatable_attribute :name, :string do
          locales [:en, :es, :fr]
        end

        translatable_attribute :description, :text do
          locales [:en, :es]
        end

        backend :redis
      end

      actions do
        defaults [:create, :read, :update, :destroy]
      end

      attributes do
        uuid_primary_key :id
        timestamps()
      end
    end

    test "adds redis key and cache attributes for redis backend" do
      attributes = Ash.Resource.Info.attribute_names(RedisProduct)

      # Should have redis key fields
      assert :name_redis_key in attributes
      assert :description_redis_key in attributes

      # Should have cache fields
      assert :name_cache in attributes
      assert :description_cache in attributes

      # Check redis key attribute
      key_attr = Ash.Resource.Info.attribute(RedisProduct, :name_redis_key)
      assert key_attr.type == Ash.Type.String
      assert key_attr.public? == false

      # Check cache attribute
      cache_attr = Ash.Resource.Info.attribute(RedisProduct, :name_cache)
      assert cache_attr.type == Ash.Type.Map
      assert cache_attr.public? == false
    end

    test "cache attributes are not public" do
      cache_attr = Ash.Resource.Info.attribute(RedisProduct, :name_cache)
      assert cache_attr.public? == false

      desc_cache = Ash.Resource.Info.attribute(RedisProduct, :description_cache)
      assert desc_cache.public? == false
    end
  end

  # Test domain
  defmodule Domain do
    use Ash.Domain

    resources do
      resource AshPhoenixTranslations.Transformers.AddTranslationStorageTest.DatabaseProduct
      resource AshPhoenixTranslations.Transformers.AddTranslationStorageTest.GettextProduct
      resource AshPhoenixTranslations.Transformers.AddTranslationStorageTest.RedisProduct
    end
  end
end
