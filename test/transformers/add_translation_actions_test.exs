defmodule AshPhoenixTranslations.Transformers.AddTranslationActionsTest do
  use ExUnit.Case

  describe "Database Backend Actions" do
    defmodule DatabaseProduct do
      use Ash.Resource,
        domain: AshPhoenixTranslations.Transformers.AddTranslationActionsTest.Domain,
        data_layer: Ash.DataLayer.Ets,
        extensions: [AshPhoenixTranslations]

      ets do
        table :test_database_actions_products
      end

      translations do
        translatable_attribute :name, :string do
          locales [:en, :es, :fr]
        end

        translatable_attribute :description, :text do
          locales [:en, :es]
        end

        backend :database
      end

      actions do
        # Using explicit actions instead of defaults to avoid transformer issues
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

    test "adds update_translation action" do
      resource_info = Ash.Resource.Info
      actions = resource_info.actions(DatabaseProduct)
      action_names = Enum.map(actions, & &1.name)

      assert :update_translation in action_names

      update_action = Enum.find(actions, &(&1.name == :update_translation))
      assert update_action.type == :update

      # Arguments will be added via DSL configuration
      # For now just check that it accepts translation fields
      assert :name_translations in update_action.accept
      assert :description_translations in update_action.accept
    end

    test "adds import_translations action" do
      resource_info = Ash.Resource.Info
      actions = resource_info.actions(DatabaseProduct)

      import_action = Enum.find(actions, &(&1.name == :import_translations))
      assert import_action != nil
      assert import_action.type == :update
    end

    test "adds export_translations action" do
      resource_info = Ash.Resource.Info
      actions = resource_info.actions(DatabaseProduct)

      export_action = Enum.find(actions, &(&1.name == :export_translations))
      assert export_action != nil
      assert export_action.type == :read
    end

    test "adds clear_translations action" do
      resource_info = Ash.Resource.Info
      actions = resource_info.actions(DatabaseProduct)

      clear_action = Enum.find(actions, &(&1.name == :clear_translations))
      assert clear_action != nil
      assert clear_action.type == :update

      # Check that it accepts translation fields
      assert :name_translations in clear_action.accept
      assert :description_translations in clear_action.accept
    end
  end

  describe "Gettext Backend Actions" do
    defmodule GettextProduct do
      use Ash.Resource,
        domain: AshPhoenixTranslations.Transformers.AddTranslationActionsTest.Domain,
        data_layer: Ash.DataLayer.Ets,
        extensions: [AshPhoenixTranslations]

      ets do
        table :test_gettext_actions_products
      end

      translations do
        translatable_attribute :name, :string do
          locales [:en, :es, :fr]
        end

        backend :gettext
      end

      actions do
        # Using explicit actions instead of defaults to avoid transformer issues
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

    test "adds translation actions for gettext backend" do
      resource_info = Ash.Resource.Info
      actions = resource_info.actions(GettextProduct)
      action_names = Enum.map(actions, & &1.name)

      # Should still have the actions, but with different behavior
      assert :update_translation in action_names
      assert :import_translations in action_names
      assert :export_translations in action_names
      assert :clear_translations in action_names

      # For gettext, update_translation shouldn't accept database fields
      update_action = Enum.find(actions, &(&1.name == :update_translation))
      assert update_action.accept == []
    end
  end

  # Arguments will be tested once they are added via DSL configuration
  # describe "Action Arguments" do
  # end

  # Test domain
  defmodule Domain do
    use Ash.Domain,
      validate_config_inclusion?: false

    resources do
      resource AshPhoenixTranslations.Transformers.AddTranslationActionsTest.DatabaseProduct
      resource AshPhoenixTranslations.Transformers.AddTranslationActionsTest.GettextProduct
    end
  end
end
