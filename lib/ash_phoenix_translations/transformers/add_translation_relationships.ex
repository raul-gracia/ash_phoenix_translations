defmodule AshPhoenixTranslations.Transformers.AddTranslationRelationships do
  @moduledoc """
  Adds translation history relationship if audit is enabled.
  
  Creates a has_many relationship to track translation changes over time,
  enabling audit trails and rollback capabilities.
  """

  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer

  @impl true
  def after?(AshPhoenixTranslations.Transformers.AddTranslationStorage), do: true
  def after?(_), do: false

  @impl true
  def transform(dsl_state) do
    # Check if audit is enabled
    audit_enabled = Transformer.get_option(dsl_state, [:translations], :audit_changes) || false
    
    if audit_enabled do
      add_translation_history_relationship(dsl_state)
    else
      {:ok, dsl_state}
    end
  end

  defp add_translation_history_relationship(dsl_state) do
    # For simplicity, use the standard TranslationHistory module
    # In production, you might want to generate a module per resource
    history_module = AshPhoenixTranslations.TranslationHistory
    
    # Add has_many relationship for translation history
    {:ok, dsl_state} =
      Ash.Resource.Builder.add_new_relationship(
        dsl_state,
        :has_many,
        :translation_history,
        history_module,
        destination_attribute: :resource_id,
        source_attribute: :id,
        public?: true,
        description: "History of translation changes for this resource"
      )
    
    # Aggregates would be added here but require different approach
    # Will be implemented in a separate transformer or via DSL
    
    {:ok, dsl_state}
  end
end