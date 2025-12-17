# Test resources for Mix task tests
# These are defined in test/support to ensure proper compilation order

defmodule AshPhoenixTranslations.MixTaskTest.TestDomain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource AshPhoenixTranslations.MixTaskTest.TestProduct
    resource AshPhoenixTranslations.MixTaskTest.TestCategory
  end
end

defmodule AshPhoenixTranslations.MixTaskTest.TestProduct do
  @moduledoc false
  use Ash.Resource,
    domain: AshPhoenixTranslations.MixTaskTest.TestDomain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshPhoenixTranslations]

  translations do
    translatable_attribute :name, :string,
      locales: [:en, :es, :fr],
      required: [:en]

    translatable_attribute :description, :text, locales: [:en, :es, :fr]

    backend :database
    cache_ttl 3600
    audit_changes false
  end

  attributes do
    uuid_primary_key :id

    attribute :sku, :string do
      allow_nil? false
    end

    timestamps()
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:sku, :name_translations, :description_translations]
      description "Creates a new product"
    end

    update :update do
      primary? true
      accept [:sku, :name_translations, :description_translations]
      require_atomic? false
      description "Updates an existing product"
    end
  end
end

defmodule AshPhoenixTranslations.MixTaskTest.TestCategory do
  @moduledoc false
  use Ash.Resource,
    domain: AshPhoenixTranslations.MixTaskTest.TestDomain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshPhoenixTranslations]

  translations do
    translatable_attribute :title, :string,
      locales: [:en, :de],
      required: [:en]

    backend :database
  end

  attributes do
    uuid_primary_key :id

    attribute :slug, :string do
      allow_nil? false
    end

    timestamps()
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:slug, :title_translations]
    end

    update :update do
      primary? true
      accept [:slug, :title_translations]
      require_atomic? false
    end
  end
end
