defmodule AshPhoenixTranslations.Transformers.AddTranslationRelationships do
  @moduledoc """
  Adds translation history relationship if audit is enabled.
  """

  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer

  @impl true
  def after?(AshPhoenixTranslations.Transformers.AddTranslationStorage), do: true
  def after?(_), do: false

  @impl true
  def transform(dsl_state) do
    # TODO: Implement relationship logic
    {:ok, dsl_state}
  end
end