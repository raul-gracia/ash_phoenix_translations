defmodule AshPhoenixTranslations.Transformers.AddTranslationChanges do
  @moduledoc """
  Adds automatic translation validation changes.
  """

  use Spark.Dsl.Transformer

  @impl true
  def after?(AshPhoenixTranslations.Transformers.AddTranslationCalculations), do: true
  def after?(_), do: false

  @impl true
  def transform(dsl_state) do
    # TODO: Implement changes logic
    {:ok, dsl_state}
  end
end