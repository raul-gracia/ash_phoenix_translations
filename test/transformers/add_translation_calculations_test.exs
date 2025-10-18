defmodule AshPhoenixTranslations.Transformers.AddTranslationCalculationsTest do
  use ExUnit.Case

  describe "Database Backend Calculations" do
    defmodule DatabaseProduct do
      use Ash.Resource,
        domain: AshPhoenixTranslations.Transformers.AddTranslationCalculationsTest.Domain,
        data_layer: Ash.DataLayer.Ets,
        extensions: [AshPhoenixTranslations]

      ets do
        table :test_database_calc_products
      end

      translations do
        translatable_attribute :name, :string do
          locales [:en, :es, :fr]
          fallback(:en)
        end

        translatable_attribute :description, :text do
          locales [:en, :es]
        end

        backend :database
      end

      actions do
        # Using explicit actions to avoid transformer issues
        create :create
        read :read
        update :update
        destroy :destroy
      end

      attributes do
        uuid_primary_key :id
        timestamps()
      end
    end

    test "adds translation calculation for each translatable attribute" do
      resource_info = Ash.Resource.Info
      calculations = resource_info.calculations(DatabaseProduct)
      calc_names = Enum.map(calculations, & &1.name)

      # Should have calculation with same name as attribute
      assert :name in calc_names
      assert :description in calc_names
    end

    test "adds all_translations calculation for each attribute" do
      resource_info = Ash.Resource.Info
      calculations = resource_info.calculations(DatabaseProduct)
      calc_names = Enum.map(calculations, & &1.name)

      # Should have all_translations calculations
      assert :name_all_translations in calc_names
      assert :description_all_translations in calc_names
    end

    test "translation calculations are public" do
      resource_info = Ash.Resource.Info

      name_calc =
        DatabaseProduct
        |> resource_info.calculations()
        |> Enum.find(&(&1.name == :name))

      assert name_calc.public? == true
    end

    test "calculations use correct modules based on backend" do
      resource_info = Ash.Resource.Info

      name_calc =
        DatabaseProduct
        |> resource_info.calculations()
        |> Enum.find(&(&1.name == :name))

      assert name_calc.calculation ==
               {AshPhoenixTranslations.Calculations.DatabaseTranslation,
                [
                  attribute_name: :name,
                  fallback: :en,
                  locales: [:en, :es, :fr],
                  backend: :database
                ]}
    end

    test "all_translations calculations use AllTranslations module" do
      resource_info = Ash.Resource.Info

      all_calc =
        DatabaseProduct
        |> resource_info.calculations()
        |> Enum.find(&(&1.name == :name_all_translations))

      {module, opts} = all_calc.calculation
      assert module == AshPhoenixTranslations.Calculations.AllTranslations
      assert opts[:attribute_name] == :name
      assert opts[:locales] == [:en, :es, :fr]
      assert opts[:backend] == :database
    end
  end

  describe "Gettext Backend Calculations" do
    defmodule GettextProduct do
      use Ash.Resource,
        domain: AshPhoenixTranslations.Transformers.AddTranslationCalculationsTest.Domain,
        data_layer: Ash.DataLayer.Ets,
        extensions: [AshPhoenixTranslations]

      ets do
        table :test_gettext_calc_products
      end

      translations do
        translatable_attribute :name, :string do
          locales [:en, :es, :fr]
        end

        backend :gettext
      end

      actions do
        create :create
        read :read
        update :update
        destroy :destroy
      end

      attributes do
        uuid_primary_key :id
        timestamps()
      end
    end

    test "adds calculations for gettext backend" do
      resource_info = Ash.Resource.Info
      calculations = resource_info.calculations(GettextProduct)
      calc_names = Enum.map(calculations, & &1.name)

      assert :name in calc_names
      assert :name_all_translations in calc_names
    end

    test "gettext calculations use GettextTranslation module" do
      resource_info = Ash.Resource.Info

      name_calc =
        GettextProduct
        |> resource_info.calculations()
        |> Enum.find(&(&1.name == :name))

      {module, _opts} = name_calc.calculation
      assert module == AshPhoenixTranslations.Calculations.GettextTranslation
    end
  end

  # Test domain
  defmodule Domain do
    use Ash.Domain,
      validate_config_inclusion?: false

    resources do
      resource AshPhoenixTranslations.Transformers.AddTranslationCalculationsTest.DatabaseProduct
      resource AshPhoenixTranslations.Transformers.AddTranslationCalculationsTest.GettextProduct
    end
  end
end
