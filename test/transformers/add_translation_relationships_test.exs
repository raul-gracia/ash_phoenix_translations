defmodule AshPhoenixTranslations.Transformers.AddTranslationRelationshipsTest do
  use ExUnit.Case

  describe "With Audit Enabled" do
    defmodule AuditProduct do
      use Ash.Resource,
        domain: AshPhoenixTranslations.Transformers.AddTranslationRelationshipsTest.Domain,
        data_layer: Ash.DataLayer.Ets,
        extensions: [AshPhoenixTranslations]

      ets do
        table :test_audit_products
      end

      translations do
        translatable_attribute :name, :string do
          locales [:en, :es, :fr]
        end

        translatable_attribute :description, :text do
          locales [:en, :es]
        end

        backend :database
        audit_changes true
      end

      actions do
        defaults [:create, :read, :update, :destroy]
      end

      attributes do
        uuid_primary_key :id
        timestamps()
      end
    end

    test "adds translation_history relationship" do
      relationships = Ash.Resource.Info.relationships(AuditProduct)

      # Should have the translation_history relationship
      history_rel = Enum.find(relationships, &(&1.name == :translation_history))
      assert history_rel != nil
      assert history_rel.type == :has_many
      assert history_rel.destination_attribute == :resource_id
      assert history_rel.source_attribute == :id
    end

    # Aggregates would be tested here once implemented via DSL or separate transformer
    # test "adds translation aggregates" do
    #   aggregates = Ash.Resource.Info.aggregates(AuditProduct)
    #   aggregate_names = Enum.map(aggregates, & &1.name)
    #   
    #   # Should have translation count aggregate
    #   assert :translation_count in aggregate_names
    #   
    #   # Should have last_translated_at aggregate  
    #   assert :last_translated_at in aggregate_names
    # end

    test "relationship is public" do
      history_rel =
        AuditProduct
        |> Ash.Resource.Info.relationships()
        |> Enum.find(&(&1.name == :translation_history))

      assert history_rel.public? == true
    end
  end

  describe "Without Audit" do
    defmodule NoAuditProduct do
      use Ash.Resource,
        domain: AshPhoenixTranslations.Transformers.AddTranslationRelationshipsTest.Domain,
        data_layer: Ash.DataLayer.Ets,
        extensions: [AshPhoenixTranslations]

      ets do
        table :test_no_audit_products
      end

      translations do
        translatable_attribute :name, :string do
          locales [:en, :es, :fr]
        end

        backend :database
        # audit_changes defaults to false
      end

      actions do
        defaults [:create, :read, :update, :destroy]
      end

      attributes do
        uuid_primary_key :id
        timestamps()
      end
    end

    test "does not add translation_history relationship" do
      relationships = Ash.Resource.Info.relationships(NoAuditProduct)

      # Should NOT have the translation_history relationship
      history_rel = Enum.find(relationships, &(&1.name == :translation_history))
      assert history_rel == nil
    end

    # Aggregates would be tested here once implemented
    # test "does not add translation aggregates" do
    #   aggregates = Ash.Resource.Info.aggregates(NoAuditProduct)
    #   aggregate_names = Enum.map(aggregates, & &1.name)
    #   
    #   # Should NOT have translation aggregates
    #   refute :translation_count in aggregate_names
    #   refute :last_translated_at in aggregate_names
    # end
  end

  describe "With Explicit Audit Disabled" do
    defmodule ExplicitNoAuditProduct do
      use Ash.Resource,
        domain: AshPhoenixTranslations.Transformers.AddTranslationRelationshipsTest.Domain,
        data_layer: Ash.DataLayer.Ets,
        extensions: [AshPhoenixTranslations]

      ets do
        table :test_explicit_no_audit_products
      end

      translations do
        translatable_attribute :name, :string do
          locales [:en, :es]
        end

        backend :database
        # Explicitly disabled
        audit_changes false
      end

      actions do
        defaults [:create, :read, :update, :destroy]
      end

      attributes do
        uuid_primary_key :id
        timestamps()
      end
    end

    test "respects explicit audit_changes false" do
      relationships = Ash.Resource.Info.relationships(ExplicitNoAuditProduct)

      # Should NOT have the translation_history relationship
      history_rel = Enum.find(relationships, &(&1.name == :translation_history))
      assert history_rel == nil
    end
  end

  # Test domain
  defmodule Domain do
    use Ash.Domain

    resources do
      resource AshPhoenixTranslations.Transformers.AddTranslationRelationshipsTest.AuditProduct
      resource AshPhoenixTranslations.Transformers.AddTranslationRelationshipsTest.NoAuditProduct

      resource AshPhoenixTranslations.Transformers.AddTranslationRelationshipsTest.ExplicitNoAuditProduct

      resource AshPhoenixTranslations.TranslationHistory
    end
  end
end
