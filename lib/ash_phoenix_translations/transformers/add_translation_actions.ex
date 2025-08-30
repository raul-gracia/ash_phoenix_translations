defmodule AshPhoenixTranslations.Transformers.AddTranslationActions do
  @moduledoc """
  Adds actions for managing translations.
  """

  use Spark.Dsl.Transformer

  @impl true
  def after?(AshPhoenixTranslations.Transformers.AddTranslationRelationships), do: true
  def after?(_), do: false

  @impl true
  def transform(dsl_state) do
    # TODO: Implement actions logic
    {:ok, dsl_state}
  end
end