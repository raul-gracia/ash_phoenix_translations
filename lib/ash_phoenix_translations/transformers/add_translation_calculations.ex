defmodule AshPhoenixTranslations.Transformers.AddTranslationCalculations do
  @moduledoc """
  Adds calculations for accessing translations in the current locale.
  
  Creates calculations for each translatable attribute that:
  - Return the translation for the current locale
  - Support fallback to default locale if configured
  - Handle missing translations gracefully
  """

  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer

  @impl true
  def after?(AshPhoenixTranslations.Transformers.AddTranslationActions), do: true
  def after?(_), do: false

  @impl true
  def transform(dsl_state) do
    backend = Transformer.get_option(dsl_state, [:translations], :backend) || :database
    
    dsl_state
    |> get_translatable_attributes()
    |> Enum.reduce({:ok, dsl_state}, fn attr, {:ok, dsl_state} ->
      dsl_state
      |> add_translation_calculation(attr, backend)
      |> add_all_translations_calculation(attr, backend)
    end)
  end

  defp get_translatable_attributes(dsl_state) do
    Transformer.get_entities(dsl_state, [:translations])
    |> Enum.filter(&is_struct(&1, AshPhoenixTranslations.TranslatableAttribute))
  end

  defp add_translation_calculation(dsl_state, attr, backend) do
    calculation_module = 
      case backend do
        :database -> AshPhoenixTranslations.Calculations.DatabaseTranslation
        :gettext -> AshPhoenixTranslations.Calculations.GettextTranslation
        :redis -> AshPhoenixTranslations.Calculations.RedisTranslation
      end
    
    {:ok, dsl_state} =
      Ash.Resource.Builder.add_new_calculation(
        dsl_state,
        attr.name,
        :string,  # The return type of the calculation
        {calculation_module, 
         attribute_name: attr.name,
         fallback: attr.fallback,
         locales: attr.locales,
         backend: backend},
        public?: true,
        description: "Current locale translation for #{attr.name}"
      )
    
    {:ok, dsl_state}
  end

  defp add_all_translations_calculation(dsl_state, attr, backend) do
    all_calc_name = :"#{attr.name}_all_translations"
    
    {:ok, dsl_state} =
      Ash.Resource.Builder.add_new_calculation(
        dsl_state,
        all_calc_name,
        :map,  # The return type - a map of translations
        {AshPhoenixTranslations.Calculations.AllTranslations,
         attribute_name: attr.name,
         locales: attr.locales,
         backend: backend},
        public?: true,
        description: "All translations for #{attr.name}"
      )
    
    {:ok, dsl_state}
  end
end