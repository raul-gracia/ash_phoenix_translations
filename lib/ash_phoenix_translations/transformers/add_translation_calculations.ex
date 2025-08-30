defmodule AshPhoenixTranslations.Transformers.AddTranslationCalculations do
  @moduledoc """
  Adds calculations for accessing translations in the current locale.
  """

  use Spark.Dsl.Transformer

  @impl true
  def after?(AshPhoenixTranslations.Transformers.AddTranslationActions), do: true
  def after?(_), do: false

  @impl true
  def transform(dsl_state) do
    # TODO: Implement calculations logic
    {:ok, dsl_state}
  end
end