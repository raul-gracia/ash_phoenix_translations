defmodule AshPhoenixTranslations.Transformers.AddTranslationActions do
  @moduledoc """
  Adds actions for managing translations.

  Creates specialized actions for:
  - Updating individual translations
  - Bulk importing translations
  - Exporting translations in various formats
  """

  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer

  @impl true
  def after?(AshPhoenixTranslations.Transformers.AddTranslationRelationships), do: true
  def after?(_), do: false

  @impl true
  def before?(Ash.Resource.Transformers.CacheActionInputs), do: true
  def before?(_), do: false

  @impl true
  def transform(dsl_state) do
    backend = Transformer.get_option(dsl_state, [:translations], :backend) || :database

    with {:ok, dsl_state} <- add_update_translation_action(dsl_state, backend),
         {:ok, dsl_state} <- add_import_translations_action(dsl_state, backend),
         {:ok, dsl_state} <- add_export_translations_action(dsl_state, backend),
         {:ok, dsl_state} <- add_clear_translations_action(dsl_state, backend) do
      {:ok, dsl_state}
    end
  end

  defp add_update_translation_action(dsl_state, backend) do
    translatable_attrs = get_translatable_attributes(dsl_state)

    # Build the accept list for all translatable attributes and locales
    accept_fields =
      Enum.flat_map(translatable_attrs, fn attr ->
        case backend do
          :database ->
            # For database backend, we update the map field directly
            [:"#{attr.name}_translations"]

          _ ->
            # For other backends, we might need different handling
            []
        end
      end)

    {:ok, dsl_state} =
      Ash.Resource.Builder.add_new_action(
        dsl_state,
        :update,
        :update_translation,
        accept: accept_fields,
        require_atomic?: false,
        description: "Update a single translation for a specific locale"
      )

    # Arguments will be added in a later phase or via manual DSL configuration
    # For now, we're just creating the basic actions

    {:ok, dsl_state}
  end

  defp add_import_translations_action(dsl_state, _backend) do
    {:ok, dsl_state} =
      Ash.Resource.Builder.add_new_action(
        dsl_state,
        :update,
        :import_translations,
        # Empty accept list
        accept: [],
        require_atomic?: false,
        description: "Bulk import translations from various formats"
      )

    # Arguments will be added via DSL or in a later phase

    {:ok, dsl_state}
  end

  defp add_export_translations_action(dsl_state, _backend) do
    {:ok, dsl_state} =
      Ash.Resource.Builder.add_new_action(
        dsl_state,
        :read,
        :export_translations,
        description: "Export translations in various formats"
      )

    # Arguments will be added via DSL or in a later phase

    {:ok, dsl_state}
  end

  defp add_clear_translations_action(dsl_state, backend) do
    translatable_attrs = get_translatable_attributes(dsl_state)

    # Build the accept list for clearing translations
    accept_fields =
      case backend do
        :database ->
          Enum.map(translatable_attrs, fn attr ->
            :"#{attr.name}_translations"
          end)

        _ ->
          []
      end

    {:ok, dsl_state} =
      Ash.Resource.Builder.add_new_action(
        dsl_state,
        :update,
        :clear_translations,
        accept: accept_fields,
        require_atomic?: false,
        description: "Clear translations for specific locales or attributes"
      )

    {:ok, dsl_state}
  end

  defp get_translatable_attributes(dsl_state) do
    Transformer.get_entities(dsl_state, [:translations])
    |> Enum.filter(&is_struct(&1, AshPhoenixTranslations.TranslatableAttribute))
  end
end
