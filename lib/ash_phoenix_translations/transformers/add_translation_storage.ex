defmodule AshPhoenixTranslations.Transformers.AddTranslationStorage do
  @moduledoc """
  Adds storage attributes for translations based on the configured backend.
  This is the first transformer that runs.

  Supports three backends:
  - Database: Uses JSONB/Map columns for storing translations
  - Gettext: No storage needed, relies on PO files
  - Redis: No storage needed, uses external Redis store
  """

  use Spark.Dsl.Transformer

  alias Ash.Resource.Builder
  alias Spark.Dsl.Transformer
  require Ash.Expr

  @impl true
  def transform(dsl_state) do
    backend = get_backend(dsl_state)
    translatable_attrs = get_translatable_attributes(dsl_state)

    # Persist the translatable attributes for later use by Info module
    dsl_state = Transformer.persist(dsl_state, :translatable_attributes, translatable_attrs)

    translatable_attrs
    |> Enum.reduce({:ok, dsl_state}, fn attr, {:ok, dsl_state} ->
      add_storage_for_attribute(dsl_state, attr, backend)
    end)
  end

  defp get_backend(dsl_state) do
    Transformer.get_option(dsl_state, [:translations], :backend) || :database
  end

  defp get_translatable_attributes(dsl_state) do
    dsl_state
    |> Transformer.get_entities([:translations])
    |> Enum.filter(&is_struct(&1, AshPhoenixTranslations.TranslatableAttribute))
  end

  defp add_storage_for_attribute(dsl_state, attr, :database) do
    # For database backend, add a JSONB/Map column for each translatable attribute
    storage_name = :"#{attr.name}_translations"

    # Build constraints for the map field
    fields =
      attr.locales
      |> Enum.map(fn locale ->
        field_type = normalize_field_type(attr.type)
        constraints = build_type_constraints(attr.type, attr.validation)

        {locale,
         [
           type: field_type,
           constraints: constraints
         ]}
      end)

    # Add the storage attribute
    # Note: Must be public/writable for update_translation action and calculations
    {:ok, dsl_state} =
      Builder.add_new_attribute(
        dsl_state,
        storage_name,
        :map,
        default: %{},
        constraints: [fields: fields],
        public?: true,
        writable?: true,
        description: "Translation storage for #{attr.name}"
      )

    {:ok, dsl_state}
  end

  defp add_storage_for_attribute(dsl_state, _attr, :gettext) do
    # Gettext doesn't need storage attributes - it uses PO files
    # We might add a virtual attribute for caching purposes later
    {:ok, dsl_state}
  end

  defp add_storage_for_attribute(dsl_state, _attr, :redis) do
    # Redis doesn't need storage attributes - it uses external Redis store
    # All translation data is stored in Redis with the pattern:
    # translations:{resource}:{record_id}:{field}:{locale}
    {:ok, dsl_state}
  end

  defp normalize_field_type(:text), do: :string
  defp normalize_field_type(type), do: type

  defp build_type_constraints(:string, validation) do
    constraints = []

    constraints =
      if max_length = Keyword.get(validation, :max_length) do
        Keyword.put(constraints, :max_length, max_length)
      else
        constraints
      end

    constraints =
      if min_length = Keyword.get(validation, :min_length) do
        Keyword.put(constraints, :min_length, min_length)
      else
        constraints
      end

    constraints
  end

  defp build_type_constraints(:text, validation) do
    # Text fields might have different constraints
    constraints = []

    if max_length = Keyword.get(validation, :max_length) do
      Keyword.put(constraints, :max_length, max_length)
    else
      constraints
    end
  end

  defp build_type_constraints(_type, _validation) do
    # For other types, return empty constraints
    []
  end
end
