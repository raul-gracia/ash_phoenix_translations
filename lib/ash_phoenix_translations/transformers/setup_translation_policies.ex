defmodule AshPhoenixTranslations.Transformers.SetupTranslationPolicies do
  @moduledoc """
  Sets up policies for translation actions if configured.
  """

  use Spark.Dsl.Transformer

  @impl true
  def after?(AshPhoenixTranslations.Transformers.AddTranslationChanges), do: true
  def after?(_), do: false

  @impl true
  def transform(dsl_state) do
    # TODO: Implement policies logic
    {:ok, dsl_state}
  end
end