defmodule AshPhoenixTranslations.Transformers.AddTranslationChangesTest do
  use ExUnit.Case

  describe "Validation Changes" do
    defmodule ValidatedProduct do
      use Ash.Resource,
        domain: AshPhoenixTranslations.Transformers.AddTranslationChangesTest.Domain,
        data_layer: Ash.DataLayer.Ets,
        extensions: [AshPhoenixTranslations]

      ets do
        table :test_validated_products
      end

      translations do
        translatable_attribute :name, :string do
          locales [:en, :es, :fr]
          # English is required
          required [:en]
        end

        translatable_attribute :description, :text do
          locales [:en, :es]
          # Both English and Spanish are required
          required [:en, :es]
        end

        backend :database
        # Enable automatic validation
        auto_validate true
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

    test "adds validation changes for required translations" do
      # Get all changes
      resource_info = Ash.Resource.Info
      actions = resource_info.actions(ValidatedProduct)
      create_action = Enum.find(actions, &(&1.name == :create))
      update_action = Enum.find(actions, &(&1.name == :update))

      # Check that validation changes are added to create and update actions
      assert Enum.any?(create_action.changes, fn change ->
               match?(
                 %Ash.Resource.Change{
                   change: {AshPhoenixTranslations.Changes.ValidateRequiredTranslations, _}
                 },
                 change
               )
             end)

      assert Enum.any?(update_action.changes, fn change ->
               match?(
                 %Ash.Resource.Change{
                   change: {AshPhoenixTranslations.Changes.ValidateRequiredTranslations, _}
                 },
                 change
               )
             end)
    end
  end

  describe "Without Auto Validation" do
    defmodule NoAutoValidateProduct do
      use Ash.Resource,
        domain: AshPhoenixTranslations.Transformers.AddTranslationChangesTest.Domain,
        data_layer: Ash.DataLayer.Ets,
        extensions: [AshPhoenixTranslations]

      ets do
        table :test_no_auto_validate_products
      end

      translations do
        translatable_attribute :name, :string do
          locales [:en, :es, :fr]
          required [:en]
        end

        backend :database
        # Disable automatic validation
        auto_validate false
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

    test "does not add validation changes when auto_validate is false" do
      resource_info = Ash.Resource.Info
      actions = resource_info.actions(NoAutoValidateProduct)
      create_action = Enum.find(actions, &(&1.name == :create))

      # Should not have validation changes
      refute Enum.any?(create_action.changes, fn change ->
               match?(
                 %Ash.Resource.Change{
                   change: {AshPhoenixTranslations.Changes.ValidateRequiredTranslations, _}
                 },
                 change
               )
             end)
    end
  end

  describe "Update Translation Action Changes" do
    defmodule UpdateActionProduct do
      use Ash.Resource,
        domain: AshPhoenixTranslations.Transformers.AddTranslationChangesTest.Domain,
        data_layer: Ash.DataLayer.Ets,
        extensions: [AshPhoenixTranslations]

      ets do
        table :test_update_action_products
      end

      translations do
        translatable_attribute :name, :string do
          locales [:en, :es]
        end

        backend :database
      end

      actions do
        create :create
        read :read
        update :update
        destroy :destroy
        # This action would be added by AddTranslationActions transformer
        update :update_translation, accept: [:name_translations]
      end

      attributes do
        uuid_primary_key :id
        timestamps()
      end
    end

    test "adds UpdateTranslation change to update_translation action" do
      resource_info = Ash.Resource.Info
      actions = resource_info.actions(UpdateActionProduct)
      update_translation_action = Enum.find(actions, &(&1.name == :update_translation))

      # Should have the UpdateTranslation change
      assert Enum.any?(update_translation_action.changes, fn change ->
               match?(
                 %Ash.Resource.Change{
                   change: {AshPhoenixTranslations.Changes.UpdateTranslation, _}
                 },
                 change
               )
             end)
    end
  end

  describe "Import Translations Action Changes" do
    defmodule ImportActionProduct do
      use Ash.Resource,
        domain: AshPhoenixTranslations.Transformers.AddTranslationChangesTest.Domain,
        data_layer: Ash.DataLayer.Ets,
        extensions: [AshPhoenixTranslations]

      ets do
        table :test_import_action_products
      end

      translations do
        translatable_attribute :name, :string do
          locales [:en, :es]
        end

        backend :database
      end

      actions do
        create :create
        read :read
        update :update
        destroy :destroy
        # This action would be added by AddTranslationActions transformer
        update :import_translations, accept: []
      end

      attributes do
        uuid_primary_key :id
        timestamps()
      end
    end

    test "adds ImportTranslations change to import_translations action" do
      resource_info = Ash.Resource.Info
      actions = resource_info.actions(ImportActionProduct)
      import_action = Enum.find(actions, &(&1.name == :import_translations))

      # Should have the ImportTranslations change
      assert Enum.any?(import_action.changes, fn change ->
               match?(
                 %Ash.Resource.Change{
                   change: {AshPhoenixTranslations.Changes.ImportTranslations, _}
                 },
                 change
               )
             end)
    end
  end

  # Test domain
  defmodule Domain do
    use Ash.Domain,
      validate_config_inclusion?: false

    resources do
      resource AshPhoenixTranslations.Transformers.AddTranslationChangesTest.ValidatedProduct
      resource AshPhoenixTranslations.Transformers.AddTranslationChangesTest.NoAutoValidateProduct
      resource AshPhoenixTranslations.Transformers.AddTranslationChangesTest.UpdateActionProduct
      resource AshPhoenixTranslations.Transformers.AddTranslationChangesTest.ImportActionProduct
    end
  end
end
