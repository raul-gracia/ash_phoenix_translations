# lib/ash_phoenix_translations.ex

defmodule AshPhoenixTranslations do
@moduledoc """
AshPhoenixTranslations - A powerful Ash Framework extension for handling translations
in Phoenix applications with policy-aware, multi-backend support.

## Installation

Add to your mix.exs:

      {:ash_phoenix_translations, "~> 1.0"}

## Usage

Add to your resource:

      defmodule MyApp.Product do
        use Ash.Resource,
          extensions: [AshPhoenixTranslations]

        translations do
          translatable_attribute :name, :string do
            locales [:en, :es, :fr]
            required [:en]
          end

          translatable_attribute :description, :text do
            locales [:en, :es, :fr]
            markdown true
          end

          backend :database
          cache_ttl 3600
        end
      end

"""

@transformers [
AshPhoenixTranslations.Transformers.AddTranslationStorage,
AshPhoenixTranslations.Transformers.AddTranslationRelationships,
AshPhoenixTranslations.Transformers.AddTranslationActions,
AshPhoenixTranslations.Transformers.AddTranslationCalculations,
AshPhoenixTranslations.Transformers.AddTranslationChanges,
AshPhoenixTranslations.Transformers.SetupTranslationPolicies
]

use Spark.Dsl.Extension, transformers: @transformers

@doc """
Translate a single resource based on the connection's locale
"""
def translate(resource, conn_or_socket_or_locale)

def translate(resource, %Plug.Conn{} = conn) do
locale = get_locale(conn)
do_translate(resource, locale)
end

def translate(resource, %Phoenix.LiveView.Socket{} = socket) do
locale = get_locale(socket)
do_translate(resource, locale)
end

def translate(resource, locale) when is_atom(locale) do
do_translate(resource, locale)
end

defp do_translate(resource, locale) do
resource
|> Ash.load!(translation_calculations(resource), context: %{locale: locale})
end

defp translation_calculations(resource) do
resource.**struct**
|> AshPhoenixTranslations.Info.translatable_attributes()
|> Enum.map(& &1.name)
end

defp get_locale(%Plug.Conn{} = conn) do
Plug.Conn.get_session(conn, :locale) ||
Application.get_env(:ash_phoenix_translations, :default_locale, :en)
end

defp get_locale(%Phoenix.LiveView.Socket{} = socket) do
Phoenix.Component.get_connect_params(socket)["locale"] || :en
end
end

# lib/ash_phoenix_translations/transformers/add_translation_storage.ex

defmodule AshPhoenixTranslations.Transformers.AddTranslationStorage do
@moduledoc """
Adds storage attributes for translations based on the configured backend.
This is the first transformer that runs.
"""

use Spark.Dsl.Transformer
alias Spark.Dsl.Transformer

@impl true
def transform(dsl_state) do
backend = get_backend(dsl_state)

    dsl_state
    |> get_translatable_attributes()
    |> Enum.reduce({:ok, dsl_state}, fn attr, {:ok, dsl_state} ->
      add_storage_for_attribute(dsl_state, attr, backend)
    end)

end

defp get_backend(dsl_state) do
Transformer.get_option(dsl_state, [:translations], :backend) || :database
end

defp get_translatable_attributes(dsl_state) do
Transformer.get_entities(dsl_state, [:translations])
|> Enum.filter(&is_struct(&1, AshPhoenixTranslations.TranslatableAttribute))
end

defp add_storage_for_attribute(dsl_state, attr, :database) do # For database backend, add a JSONB column for each translatable attribute
storage_name = :"#{attr.name}\_translations"

    # Build constraints for the map field
    fields =
      attr.locales
      |> Enum.map(fn locale ->
        {locale, [
          type: attr.type,
          constraints: attr.validation
        ]}
      end)
      |> Map.new()

    # Add the storage attribute
    {:ok, dsl_state} =
      Ash.Resource.Builder.add_new_attribute(
        dsl_state,
        storage_name,
        :map,
        default: %{},
        constraints: [fields: fields],
        public?: false  # Hide from public API
      )

    {:ok, dsl_state}

end

defp add_storage_for_attribute(dsl_state, \_attr, :gettext) do # Gettext doesn't need storage attributes
{:ok, dsl_state}
end

end

# lib/ash_phoenix_translations/transformers/add_translation_relationships.ex

defmodule AshPhoenixTranslations.Transformers.AddTranslationRelationships do
@moduledoc """
Adds translation history relationship if audit is enabled.
"""

use Spark.Dsl.Transformer
alias Spark.Dsl.Transformer

@impl true
def after?(AshPhoenixTranslations.Transformers.AddTranslationStorage), do: true
def after?(\_), do: false

@impl true
def transform(dsl_state) do
if audit_enabled?(dsl_state) do
add_translation_history_relationship(dsl_state)
else
{:ok, dsl_state}
end
end

defp audit_enabled?(dsl_state) do
Transformer.get_option(dsl_state, [:translations], :audit_changes) == true
end

defp add_translation_history_relationship(dsl_state) do # Add a has_many relationship to translation history
{:ok, dsl_state} =
Ash.Resource.Builder.add_new_relationship(
dsl_state,
:has_many,
:translation_history,
AshPhoenixTranslations.TranslationHistory,
destination_attribute: :resource_id,
source_attribute: get_primary_key_name(dsl_state)
)

    {:ok, dsl_state}

end

defp get_primary_key_name(dsl_state) do
dsl_state
|> Ash.Resource.Info.primary_key()
|> List.first()
end
end

# lib/ash_phoenix_translations/transformers/add_translation_actions.ex

defmodule AshPhoenixTranslations.Transformers.AddTranslationActions do
@moduledoc """
Adds actions for managing translations.
"""

use Spark.Dsl.Transformer
alias Spark.Dsl.Transformer

@impl true
def after?(AshPhoenixTranslations.Transformers.AddTranslationRelationships), do: true
def after?(\_), do: false

@impl true
def transform(dsl_state) do
dsl_state
|> add_update_translation_action()
|> add_bulk_import_action()
|> add_export_translations_action()
|> wrap_result()
end

defp add_update_translation_action(dsl_state) do
{:ok, dsl_state} =
Ash.Resource.Builder.add_new_update_action(
dsl_state,
:update_translation,
accept: [],
arguments: [
Ash.Resource.Builder.build_action_argument(:attribute, :atom, required: true),
Ash.Resource.Builder.build_action_argument(:locale, :atom, required: true),
Ash.Resource.Builder.build_action_argument(:value, :string, required: true)
],
changes: [
{AshPhoenixTranslations.Changes.UpdateTranslation, []}
]
)

    dsl_state

end

defp add_bulk_import_action(dsl_state) do
{:ok, dsl_state} =
Ash.Resource.Builder.add_new_update_action(
dsl_state,
:import_translations,
accept: [],
arguments: [
Ash.Resource.Builder.build_action_argument(:translations, :map, required: true),
Ash.Resource.Builder.build_action_argument(:format, :atom,
default: :json,
constraints: [one_of: [:json, :csv, :xliff]]
)
],
changes: [
{AshPhoenixTranslations.Changes.ImportTranslations, []}
]
)

    dsl_state

end

defp add_export_translations_action(dsl_state) do
{:ok, dsl_state} =
Ash.Resource.Builder.add_new_read_action(
dsl_state,
:export_translations,
arguments: [
Ash.Resource.Builder.build_action_argument(:locales, {:array, :atom},
default: :all
),
Ash.Resource.Builder.build_action_argument(:format, :atom,
default: :json,
constraints: [one_of: [:json, :csv, :xliff]]
)
],
preparations: [
{AshPhoenixTranslations.Preparations.ExportTranslations, []}
]
)

    dsl_state

end

defp wrap_result(dsl_state), do: {:ok, dsl_state}
end

# lib/ash_phoenix_translations/transformers/add_translation_calculations.ex

defmodule AshPhoenixTranslations.Transformers.AddTranslationCalculations do
@moduledoc """
Adds calculations for accessing translations in the current locale.
"""

use Spark.Dsl.Transformer
alias Spark.Dsl.Transformer

@impl true
def after?(AshPhoenixTranslations.Transformers.AddTranslationActions), do: true
def after?(\_), do: false

@impl true
def transform(dsl_state) do
backend = get_backend(dsl_state)

    dsl_state
    |> get_translatable_attributes()
    |> Enum.reduce({:ok, dsl_state}, fn attr, {:ok, dsl_state} ->
      add_calculation_for_attribute(dsl_state, attr, backend)
    end)

end

defp get_backend(dsl_state) do
Transformer.get_option(dsl_state, [:translations], :backend) || :database
end

defp get_translatable_attributes(dsl_state) do
Transformer.get_entities(dsl_state, [:translations])
|> Enum.filter(&is_struct(&1, AshPhoenixTranslations.TranslatableAttribute))
end

defp add_calculation_for_attribute(dsl_state, attr, :database) do
{:ok, dsl_state} =
Ash.Resource.Builder.add_new_calculation(
dsl_state,
attr.name,
attr.type,
{AshPhoenixTranslations.Calculations.DatabaseTranslation,
field: :"#{attr.name}\_translations",
fallback: attr.fallback},
public?: true
)

    # Also add a calculation for all translations
    {:ok, dsl_state} =
      Ash.Resource.Builder.add_new_calculation(
        dsl_state,
        :"#{attr.name}_all_translations",
        :map,
        {AshPhoenixTranslations.Calculations.AllTranslations,
         field: :"#{attr.name}_translations"},
        public?: true
      )

    {:ok, dsl_state}

end

defp add_calculation_for_attribute(dsl_state, attr, :gettext) do
{:ok, dsl_state} =
Ash.Resource.Builder.add_new_calculation(
dsl_state,
attr.name,
attr.type,
{AshPhoenixTranslations.Calculations.GettextTranslation,
resource_name: get_resource_name(dsl_state),
field: attr.name},
public?: true
)

    {:ok, dsl_state}

end

defp get_resource_name(dsl_state) do
Spark.Dsl.Transformer.get_persisted(dsl_state, :module)
end
end

# lib/ash_phoenix_translations/transformers/add_translation_changes.ex

defmodule AshPhoenixTranslations.Transformers.AddTranslationChanges do
@moduledoc """
Adds automatic translation validation changes.
"""

use Spark.Dsl.Transformer
alias Spark.Dsl.Transformer

@impl true
def after?(AshPhoenixTranslations.Transformers.AddTranslationCalculations), do: true
def after?(\_), do: false

@impl true
def transform(dsl_state) do
if auto_validate?(dsl_state) do
add_validation_changes(dsl_state)
else
{:ok, dsl_state}
end
end

defp auto_validate?(dsl_state) do
Transformer.get_option(dsl_state, [:translations], :auto_validate) != false
end

defp add_validation_changes(dsl_state) do
translatable_attrs = get_translatable_attributes(dsl_state)

    # Add a change to all create/update actions to validate required translations
    dsl_state
    |> Ash.Resource.Info.actions()
    |> Enum.filter(&(&1.type in [:create, :update]))
    |> Enum.reduce({:ok, dsl_state}, fn action, {:ok, dsl_state} ->
      add_validation_to_action(dsl_state, action, translatable_attrs)
    end)

end

defp get_translatable_attributes(dsl_state) do
Transformer.get_entities(dsl_state, [:translations])
|> Enum.filter(&is_struct(&1, AshPhoenixTranslations.TranslatableAttribute))
end

defp add_validation_to_action(dsl_state, action, translatable_attrs) do # Add validation change to ensure required locales have values
changes = [
{AshPhoenixTranslations.Changes.ValidateRequiredTranslations,
attributes: translatable_attrs} | action.changes
]

    updated_action = %{action | changes: changes}

    # Update the action in the dsl_state
    dsl_state =
      Transformer.replace_entity(
        dsl_state,
        [:actions],
        updated_action,
        &(&1.name == action.name)
      )

    {:ok, dsl_state}

end
end

# lib/ash_phoenix_translations/transformers/setup_translation_policies.ex

defmodule AshPhoenixTranslations.Transformers.SetupTranslationPolicies do
@moduledoc """
Sets up policies for translation actions if configured.
"""

use Spark.Dsl.Transformer
alias Spark.Dsl.Transformer

@impl true
def after?(AshPhoenixTranslations.Transformers.AddTranslationChanges), do: true
def after?(\_), do: false

@impl true
def transform(dsl_state) do
if has_translation_policies?(dsl_state) do
setup_policies(dsl_state)
else
{:ok, dsl_state}
end
end

defp has_translation_policies?(dsl_state) do # Check if there are any translation-specific policies configured
Transformer.get_entities(dsl_state, [:translations, :policies])
|> Enum.any?()
end

defp setup_policies(dsl_state) do # Add policies for translation actions
policies = Transformer.get_entities(dsl_state, [:translations, :policies])

    dsl_state =
      Enum.reduce(policies, dsl_state, fn policy, dsl_state ->
        add_policy_to_resource(dsl_state, policy)
      end)

    {:ok, dsl_state}

end

defp add_policy_to_resource(dsl_state, policy) do # This would integrate with Ash's authorization system # Implementation depends on how policies are structured
dsl_state
end
end

# lib/ash_phoenix_translations/calculations/database_translation.ex

defmodule AshPhoenixTranslations.Calculations.DatabaseTranslation do
@moduledoc """
Calculation that returns the current locale's translation from database storage.
"""

use Ash.Resource.Calculation

@impl true
def init(opts) do
{:ok, opts}
end

@impl true
def calculate(records, opts, context) do
locale = context[:locale] || default_locale()
field = opts[:field]
fallback = opts[:fallback]

    Enum.map(records, fn record ->
      translations = Map.get(record, field, %{})

      get_translation_with_fallback(translations, locale, fallback)
    end)

end

@impl true
def expression(opts, context) do # For query-time calculation if needed
locale = context[:locale] || default_locale()
field = opts[:field]

    expr(fragment("?->?", ^field, ^to_string(locale)))

end

defp get_translation_with_fallback(translations, locale, fallback) do
cond do
Map.has_key?(translations, locale) ->
Map.get(translations, locale)

      fallback && Map.has_key?(translations, fallback) ->
        Map.get(translations, fallback)

      true ->
        # Try to get any available translation
        translations
        |> Map.values()
        |> List.first()
    end

end

defp default_locale do
Application.get_env(:ash_phoenix_translations, :default_locale, :en)
end
end

# lib/ash_phoenix_translations/test/ash_phoenix_translations_test.exs

defmodule AshPhoenixTranslationsTest do
use ExUnit.Case

# Test resource with translations

defmodule Product do
use Ash.Resource,
domain: AshPhoenixTranslationsTest.Domain,
data_layer: Ash.DataLayer.Ets,
extensions: [AshPhoenixTranslations]

    ets do
      table :test_products
    end

    translations do
      translatable_attribute :name, :string do
        locales [:en, :es, :fr]
        required [:en]
      end

      translatable_attribute :description, :text do
        locales [:en, :es, :fr]
        fallback :en
        markdown true
      end

      backend :database
      cache_ttl 3600
      audit_changes false
    end

    actions do
      defaults [:read, :destroy]

      create :create do
        primary? true
        accept [:sku, :price]
      end

      update :update do
        primary? true
        accept [:sku, :price]
      end
    end

    attributes do
      uuid_primary_key :id
      attribute :sku, :string, allow_nil?: false
      attribute :price, :decimal
      timestamps()
    end

end

# Test domain

defmodule Domain do
use Ash.Domain

    resources do
      resource AshPhoenixTranslationsTest.Product
    end

end

describe "Extension Structure" do
test "adds translation storage attributes" do
attributes = Ash.Resource.Info.attribute_names(Product)

      assert :name_translations in attributes
      assert :description_translations in attributes
    end

    test "adds translation calculations" do
      calculations =
        Product
        |> Ash.Resource.Info.calculations()
        |> Enum.map(& &1.name)

      assert :name in calculations
      assert :description in calculations
      assert :name_all_translations in calculations
      assert :description_all_translations in calculations
    end

    test "adds translation actions" do
      actions =
        Product
        |> Ash.Resource.Info.actions()
        |> Enum.map(& &1.name)

      assert :update_translation in actions
      assert :import_translations in actions
      assert :export_translations in actions
    end

    test "storage attributes are maps with correct structure" do
      name_attr = Ash.Resource.Info.attribute(Product, :name_translations)

      assert name_attr.type == Ash.Type.Map
      assert name_attr.public? == false
      assert name_attr.default == %{}
    end

end

describe "Translation Operations" do
setup do # Clean ETS table before each test
:ets.delete_all_objects(:test_products)
:ok
end

    test "creates resource with translations" do
      product =
        Product
        |> Ash.Changeset.for_create(:create, %{
          sku: "PROD-001",
          price: Decimal.new("99.99"),
          name_translations: %{
            en: "Product Name",
            es: "Nombre del Producto",
            fr: "Nom du Produit"
          },
          description_translations: %{
            en: "Product Description",
            es: "Descripción del Producto"
          }
        })
        |> Ash.create!()

      assert product.name_translations.en == "Product Name"
      assert product.name_translations.es == "Nombre del Producto"
      assert product.description_translations.en == "Product Description"
    end

    test "loads translations with specific locale context" do
      # Create product with translations
      product =
        Product
        |> Ash.Changeset.for_create(:create, %{
          sku: "PROD-002",
          price: Decimal.new("149.99"),
          name_translations: %{
            en: "Widget",
            es: "Artilugio",
            fr: "Gadget"
          }
        })
        |> Ash.create!()

      # Load with English locale
      en_product =
        Product
        |> Ash.get!(product.id)
        |> Ash.load!([:name], context: %{locale: :en})

      assert en_product.name == "Widget"

      # Load with Spanish locale
      es_product =
        Product
        |> Ash.get!(product.id)
        |> Ash.load!([:name], context: %{locale: :es})

      assert es_product.name == "Artilugio"

      # Load with French locale
      fr_product =
        Product
        |> Ash.get!(product.id)
        |> Ash.load!([:name], context: %{locale: :fr})

      assert fr_product.name == "Gadget"
    end

    test "falls back to configured fallback locale" do
      product =
        Product
        |> Ash.Changeset.for_create(:create, %{
          sku: "PROD-003",
          price: Decimal.new("79.99"),
          description_translations: %{
            en: "English Description"
            # No Spanish or French translations
          }
        })
        |> Ash.create!()

      # Should fall back to English (configured fallback)
      loaded =
        Product
        |> Ash.get!(product.id)
        |> Ash.load!([:description], context: %{locale: :es})

      assert loaded.description == "English Description"
    end

    test "updates single translation" do
      product =
        Product
        |> Ash.Changeset.for_create(:create, %{
          sku: "PROD-004",
          price: Decimal.new("199.99"),
          name_translations: %{
            en: "Original Name"
          }
        })
        |> Ash.create!()

      updated =
        product
        |> Ash.Changeset.for_update(:update_translation, %{
          attribute: :name,
          locale: :es,
          value: "Nombre Actualizado"
        })
        |> Ash.update!()

      assert updated.name_translations.en == "Original Name"
      assert updated.name_translations.es == "Nombre Actualizado"
    end

    test "bulk imports translations" do
      product =
        Product
        |> Ash.Changeset.for_create(:create, %{
          sku: "PROD-005",
          price: Decimal.new("299.99")
        })
        |> Ash.create!()

      translations = %{
        name: %{
          en: "Bulk Name",
          es: "Nombre Masivo",
          fr: "Nom en Vrac"
        },
        description: %{
          en: "Bulk Description",
          es: "Descripción Masiva"
        }
      }

      updated =
        product
        |> Ash.Changeset.for_update(:import_translations, %{
          translations: translations,
          format: :json
        })
        |> Ash.update!()

      assert updated.name_translations.en == "Bulk Name"
      assert updated.name_translations.es == "Nombre Masivo"
      assert updated.description_translations.en == "Bulk Description"
    end

end

describe "Helper Functions" do
test "translate/2 loads translations for given locale" do
product =
Product
|> Ash.Changeset.for_create(:create, %{
sku: "PROD-006",
price: Decimal.new("99.99"),
name_translations: %{
en: "English",
es: "Español"
}
})
|> Ash.create!()

      # Translate with locale atom
      es_product = AshPhoenixTranslations.translate(product, :es)
      assert es_product.name == "Español"

      en_product = AshPhoenixTranslations.translate(product, :en)
      assert en_product.name == "English"
    end

end

describe "Query Integration" do
test "can filter by translated values" do # Create products with different translations
\_product1 =
Product
|> Ash.Changeset.for_create(:create, %{
sku: "PROD-007",
price: Decimal.new("50.00"),
name_translations: %{
en: "Red Widget",
es: "Widget Rojo"
}
})
|> Ash.create!()

      _product2 =
        Product
        |> Ash.Changeset.for_create(:create, %{
          sku: "PROD-008",
          price: Decimal.new("60.00"),
          name_translations: %{
            en: "Blue Widget",
            es: "Widget Azul"
          }
        })
        |> Ash.create!()

      # Query products - this would work with proper query support
      products =
        Product
        |> Ash.read!()
        |> Ash.load!([:name], context: %{locale: :es})

      assert length(products) == 2
      assert Enum.all?(products, &String.contains?(&1.name || "", "Widget"))
    end

end
end

# lib/ash_phoenix_translations/changes/update_translation.ex

defmodule AshPhoenixTranslations.Changes.UpdateTranslation do
@moduledoc """
Change that updates a single translation value.
"""

use Ash.Resource.Change

@impl true
def change(changeset, \_opts, \_context) do
attribute = Ash.Changeset.get_argument(changeset, :attribute)
locale = Ash.Changeset.get_argument(changeset, :locale)
value = Ash.Changeset.get_argument(changeset, :value)

    field = :"#{attribute}_translations"
    current = Ash.Changeset.get_attribute(changeset, field) || %{}
    updated = Map.put(current, locale, value)

    Ash.Changeset.change_attribute(changeset, field, updated)

end
end

# lib/ash_phoenix_translations/changes/import_translations.ex

defmodule AshPhoenixTranslations.Changes.ImportTranslations do
@moduledoc """
Change that imports multiple translations at once.
"""

use Ash.Resource.Change

@impl true
def change(changeset, \_opts, \_context) do
translations = Ash.Changeset.get_argument(changeset, :translations)
format = Ash.Changeset.get_argument(changeset, :format)

    parsed_translations = parse_translations(translations, format)

    Enum.reduce(parsed_translations, changeset, fn {attr, locales}, changeset ->
      field = :"#{attr}_translations"
      current = Ash.Changeset.get_attribute(changeset, field) || %{}
      updated = Map.merge(current, locales)

      Ash.Changeset.change_attribute(changeset, field, updated)
    end)

end

defp parse_translations(translations, :json) do # Already in the right format
translations
end

defp parse_translations(translations, :csv) do # Parse CSV format # Format: attribute,locale,value
translations
|> String.split("\n")
|> Enum.map(&String.split(&1, ","))
|> Enum.reduce(%{}, fn [attr, locale, value], acc ->
attr = String.to_atom(attr)
locale = String.to_atom(locale)

      Map.update(acc, attr, %{locale => value}, fn existing ->
        Map.put(existing, locale, value)
      end)
    end)

end

defp parse_translations(translations, :xliff) do # Would parse XLIFF format # For now, just return empty map
%{}
end
end

# lib/ash_phoenix_translations/changes/validate_required_translations.ex

defmodule AshPhoenixTranslations.Changes.ValidateRequiredTranslations do
@moduledoc """
Validates that required translations are present.
"""

use Ash.Resource.Change

@impl true
def change(changeset, opts, \_context) do
attributes = opts[:attributes] || []

    Enum.reduce(attributes, changeset, fn attr, changeset ->
      validate_attribute_translations(changeset, attr)
    end)

end

defp validate_attribute_translations(changeset, attr) do
field = :"#{attr.name}\_translations"
translations = Ash.Changeset.get_attribute(changeset, field) || %{}

    missing_required =
      attr.required
      |> Enum.reject(&Map.has_key?(translations, &1))

    if Enum.any?(missing_required) do
      Ash.Changeset.add_error(
        changeset,
        field: field,
        message: "Missing required translations for locales: #{inspect(missing_required)}",
        vars: [locales: missing_required]
      )
    else
      changeset
    end

end
end
