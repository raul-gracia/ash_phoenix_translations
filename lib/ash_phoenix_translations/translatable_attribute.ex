defmodule AshPhoenixTranslations.TranslatableAttribute do
  @moduledoc """
  Defines a translatable attribute in an Ash resource.

  This module provides the DSL entity for defining translatable attributes
  with support for multiple locales, validation, and various configurations.
  """

  defstruct [
    :name,
    :type,
    :locales,
    :required,
    :fallback,
    :markdown,
    :validation,
    :constraints,
    :description
  ]

  @type t :: %__MODULE__{
          name: atom(),
          type: atom(),
          locales: [atom()],
          required: [atom()],
          fallback: atom() | nil,
          markdown: boolean(),
          validation: keyword(),
          constraints: keyword(),
          description: String.t() | nil
        }

  @doc false
  def entity do
    %Spark.Dsl.Entity{
      name: :translatable_attribute,
      target: __MODULE__,
      args: [:name, :type],
      schema: schema(),
      transform: {__MODULE__, :transform, []}
    }
  end

  @doc false
  def schema do
    [
      name: [
        type: :atom,
        required: true,
        doc: "The name of the translatable attribute"
      ],
      type: [
        type: :atom,
        required: true,
        doc: "The data type of the attribute (e.g., :string, :text)"
      ],
      locales: [
        type: {:list, :atom},
        required: true,
        doc: "List of supported locales for this attribute"
      ],
      required: [
        type: {:list, :atom},
        default: [],
        doc: "List of locales that are required to have a value"
      ],
      fallback: [
        type: :atom,
        default: nil,
        doc: "The locale to fall back to if the requested locale is not available"
      ],
      markdown: [
        type: :boolean,
        default: false,
        doc: "Whether the attribute content supports markdown formatting"
      ],
      validation: [
        type: :keyword_list,
        default: [],
        doc: "Validation rules for the translated content"
      ],
      constraints: [
        type: :keyword_list,
        default: [],
        doc: "Additional constraints for the attribute"
      ],
      description: [
        type: {:or, [:string, nil]},
        default: nil,
        doc: "Description of the translatable attribute"
      ]
    ]
  end

  @doc false
  def transform(entity) do
    entity =
      entity
      |> validate_locales()
      |> validate_required_locales()
      |> validate_fallback_locale()
      |> set_default_validation()

    {:ok, entity}
  end

  defp validate_locales(%{locales: locales} = entity) when is_list(locales) and locales != [] do
    entity
  end

  defp validate_locales(_entity) do
    raise Spark.Error.DslError,
      message: "translatable_attribute must have at least one locale defined",
      path: [:translations, :translatable_attribute]
  end

  defp validate_required_locales(%{required: required, locales: locales} = entity) do
    invalid_required = Enum.reject(required, &(&1 in locales))

    if invalid_required == [] do
      entity
    else
      raise Spark.Error.DslError,
        message:
          "Required locales #{inspect(invalid_required)} are not in the supported locales #{inspect(locales)}",
        path: [:translations, :translatable_attribute]
    end
  end

  defp validate_fallback_locale(%{fallback: nil} = entity), do: entity

  defp validate_fallback_locale(%{fallback: fallback, locales: locales} = entity) do
    if fallback in locales do
      entity
    else
      raise Spark.Error.DslError,
        message:
          "Fallback locale #{inspect(fallback)} is not in the supported locales #{inspect(locales)}",
        path: [:translations, :translatable_attribute]
    end
  end

  defp set_default_validation(%{type: type, validation: validation} = entity) do
    default_validation = default_validation_for_type(type)

    %{entity | validation: Keyword.merge(default_validation, validation)}
  end

  defp default_validation_for_type(:string) do
    [max_length: 255]
  end

  defp default_validation_for_type(:text) do
    []
  end

  defp default_validation_for_type(_) do
    []
  end
end
