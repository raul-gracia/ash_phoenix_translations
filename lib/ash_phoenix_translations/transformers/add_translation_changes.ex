defmodule AshPhoenixTranslations.Transformers.AddTranslationChanges do
  @moduledoc """
  Adds automatic translation validation changes.

  Adds changes to actions that:
  - Validate required translations
  - Update translation storage on changes
  - Handle import/export operations
  """

  use Spark.Dsl.Transformer

  alias Ash.Resource.Builder
  alias Spark.Dsl.Transformer

  @impl true
  def after?(AshPhoenixTranslations.Transformers.AddTranslationCalculations), do: true
  def after?(_), do: false

  @impl true
  def transform(dsl_state) do
    backend = Transformer.get_option(dsl_state, [:translations], :backend) || :database
    auto_validate = Transformer.get_option(dsl_state, [:translations], :auto_validate) !== false

    with {:ok, dsl_state} <-
           (if auto_validate do
              add_validation_changes(dsl_state, backend)
            else
              {:ok, dsl_state}
            end),
         {:ok, dsl_state} <- add_update_changes(dsl_state, backend),
         {:ok, dsl_state} <- add_import_changes(dsl_state, backend) do
      {:ok, dsl_state}
    end
  end

  defp add_validation_changes(dsl_state, backend) do
    translatable_attrs = get_translatable_attributes(dsl_state)

    # Add validation change to create and update actions (but not update_translation)
    actions = Transformer.get_entities(dsl_state, [:actions])

    Enum.reduce(actions, {:ok, dsl_state}, fn action, {:ok, dsl_state} ->
      # Skip validation for update_translation and clear_translations actions
      if action.type in [:create, :update] and
           action.name not in [:update_translation, :clear_translations] do
        add_validation_to_action(dsl_state, action, translatable_attrs, backend)
      else
        {:ok, dsl_state}
      end
    end)
  end

  defp add_validation_to_action(dsl_state, action, translatable_attrs, backend) do
    # For each translatable attribute with required locales, add validation
    Enum.reduce(translatable_attrs, {:ok, dsl_state}, fn attr, {:ok, dsl_state} ->
      if Enum.any?(attr.required || []) do
        # Build a change entity
        {:ok, change} =
          Builder.build_action_change(
            {AshPhoenixTranslations.Changes.ValidateRequiredTranslations,
             attribute_name: attr.name,
             required_locales: attr.required,
             backend: backend,
             action_name: action.name},
            only_when_valid?: true
          )

        # Add it to the action's changes
        updated_action = %{action | changes: [change | action.changes]}

        # Replace the action in the DSL state
        dsl_state =
          Transformer.replace_entity(
            dsl_state,
            [:actions],
            updated_action,
            &(&1.name == action.name)
          )

        {:ok, dsl_state}
      else
        {:ok, dsl_state}
      end
    end)
  end

  defp add_update_changes(dsl_state, backend) do
    # Add change to update_translation action if it exists
    actions = Transformer.get_entities(dsl_state, [:actions])

    update_translation_action = Enum.find(actions, &(&1.name == :update_translation))

    if update_translation_action do
      # Build a change entity for UpdateTranslation
      {:ok, change} =
        Builder.build_action_change(
          {AshPhoenixTranslations.Changes.UpdateTranslation,
           backend: backend, action_name: :update_translation}
        )

      # Add it to the action's changes
      updated_action = %{
        update_translation_action
        | changes: [change | update_translation_action.changes]
      }

      # Replace the action in the DSL state
      dsl_state =
        Transformer.replace_entity(
          dsl_state,
          [:actions],
          updated_action,
          &(&1.name == :update_translation)
        )

      {:ok, dsl_state}
    else
      {:ok, dsl_state}
    end
  end

  defp add_import_changes(dsl_state, backend) do
    # Add change to import_translations action if it exists
    actions = Transformer.get_entities(dsl_state, [:actions])

    import_action = Enum.find(actions, &(&1.name == :import_translations))

    if import_action do
      # Build a change entity for ImportTranslations
      {:ok, change} =
        Builder.build_action_change(
          {AshPhoenixTranslations.Changes.ImportTranslations,
           backend: backend, action_name: :import_translations}
        )

      # Add it to the action's changes
      updated_action = %{import_action | changes: [change | import_action.changes]}

      # Replace the action in the DSL state
      dsl_state =
        Transformer.replace_entity(
          dsl_state,
          [:actions],
          updated_action,
          &(&1.name == :import_translations)
        )

      {:ok, dsl_state}
    else
      {:ok, dsl_state}
    end
  end

  defp get_translatable_attributes(dsl_state) do
    dsl_state
    |> Transformer.get_entities([:translations])
    |> Enum.filter(&is_struct(&1, AshPhoenixTranslations.TranslatableAttribute))
  end
end
