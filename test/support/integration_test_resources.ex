# Integration test resources for embedded translations and fallback testing
# These resources are fully configured with AshPhoenixTranslations extension
# to enable tests that require proper Ash DSL introspection

defmodule AshPhoenixTranslations.IntegrationTest.EmbeddedAddress do
  @moduledoc false
  use Ash.Resource,
    data_layer: :embedded,
    extensions: [AshPhoenixTranslations]

  attributes do
    uuid_primary_key :id
    attribute :postal_code, :string, public?: true
  end

  translations do
    translatable_attribute :street, :string, locales: [:en, :es, :fr]
    translatable_attribute :city, :string, locales: [:en, :es, :fr]
    backend :database
  end
end

defmodule AshPhoenixTranslations.IntegrationTest.EmbeddedFeature do
  @moduledoc false
  use Ash.Resource,
    data_layer: :embedded,
    extensions: [AshPhoenixTranslations]

  attributes do
    uuid_primary_key :id
    attribute :code, :string, public?: true
  end

  translations do
    translatable_attribute :name, :string, locales: [:en, :es, :fr]
    translatable_attribute :description, :text, locales: [:en, :es, :fr]
    backend :database
  end
end

defmodule AshPhoenixTranslations.IntegrationTest.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource AshPhoenixTranslations.IntegrationTest.UserWithEmbedded
    resource AshPhoenixTranslations.IntegrationTest.ProductWithFeatures
  end
end

defmodule AshPhoenixTranslations.IntegrationTest.UserWithEmbedded do
  @moduledoc false
  use Ash.Resource,
    domain: AshPhoenixTranslations.IntegrationTest.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshPhoenixTranslations],
    validate_domain_inclusion?: false

  attributes do
    uuid_primary_key :id
    attribute :email, :string, public?: true

    attribute :address, AshPhoenixTranslations.IntegrationTest.EmbeddedAddress, public?: true
  end

  translations do
    translatable_attribute :name, :string, locales: [:en, :es, :fr], required: [:en]
    translatable_attribute :bio, :text, locales: [:en, :es, :fr]
    backend :database
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:email, :address, :name_translations, :bio_translations]
    end

    update :update do
      primary? true
      accept [:email, :address, :name_translations, :bio_translations]
      require_atomic? false
    end
  end
end

defmodule AshPhoenixTranslations.IntegrationTest.ProductWithFeatures do
  @moduledoc false
  use Ash.Resource,
    domain: AshPhoenixTranslations.IntegrationTest.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshPhoenixTranslations],
    validate_domain_inclusion?: false

  attributes do
    uuid_primary_key :id
    attribute :sku, :string, allow_nil?: false, public?: true

    attribute :features, {:array, AshPhoenixTranslations.IntegrationTest.EmbeddedFeature},
      public?: true
  end

  translations do
    translatable_attribute :name, :string, locales: [:en, :es, :fr], required: [:en]
    translatable_attribute :description, :text, locales: [:en, :es, :fr]
    backend :database
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:sku, :features, :name_translations, :description_translations]
    end

    update :update do
      primary? true
      accept [:sku, :features, :name_translations, :description_translations]
      require_atomic? false
    end
  end
end
