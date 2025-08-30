defmodule AshPhoenixTranslations.Info do
  @moduledoc """
  Introspection module for AshPhoenixTranslations extension.
  
  Provides functions to retrieve translation configuration and metadata
  from resources that use the AshPhoenixTranslations extension.
  """

  use Spark.InfoGenerator, extension: AshPhoenixTranslations, sections: [:translations]

  @doc """
  Returns all translatable attributes for a resource.
  """
  @spec translatable_attributes(Ash.Resource.t() | Spark.Dsl.t()) ::
          [AshPhoenixTranslations.TranslatableAttribute.t()]
  def translatable_attributes(resource) do
    resource
    |> translations()
    |> Map.get(:translatable_attributes, [])
  end

  @doc """
  Returns the configured backend for translations.
  """
  @spec backend(Ash.Resource.t() | Spark.Dsl.t()) :: :database | :gettext | :redis
  def backend(resource) do
    resource
    |> translations()
    |> Map.get(:backend, :database)
  end

  @doc """
  Returns the cache TTL in seconds.
  """
  @spec cache_ttl(Ash.Resource.t() | Spark.Dsl.t()) :: pos_integer()
  def cache_ttl(resource) do
    resource
    |> translations()
    |> Map.get(:cache_ttl, 3600)
  end

  @doc """
  Returns whether translation changes should be audited.
  """
  @spec audit_changes?(Ash.Resource.t() | Spark.Dsl.t()) :: boolean()
  def audit_changes?(resource) do
    resource
    |> translations()
    |> Map.get(:audit_changes, false)
  end

  @doc """
  Returns whether translations should be automatically validated.
  """
  @spec auto_validate?(Ash.Resource.t() | Spark.Dsl.t()) :: boolean()
  def auto_validate?(resource) do
    resource
    |> translations()
    |> Map.get(:auto_validate, true)
  end

  @doc """
  Returns a specific translatable attribute by name.
  """
  @spec translatable_attribute(Ash.Resource.t() | Spark.Dsl.t(), atom()) ::
          AshPhoenixTranslations.TranslatableAttribute.t() | nil
  def translatable_attribute(resource, name) do
    resource
    |> translatable_attributes()
    |> Enum.find(&(&1.name == name))
  end

  @doc """
  Returns all supported locales across all translatable attributes.
  """
  @spec supported_locales(Ash.Resource.t() | Spark.Dsl.t()) :: [atom()]
  def supported_locales(resource) do
    resource
    |> translatable_attributes()
    |> Enum.flat_map(& &1.locales)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Returns whether a resource has any translatable attributes.
  """
  @spec translatable?(Ash.Resource.t() | Spark.Dsl.t()) :: boolean()
  def translatable?(resource) do
    resource
    |> translatable_attributes()
    |> Enum.any?()
  end

  @doc """
  Returns the translation storage field name for an attribute.
  """
  @spec storage_field(atom()) :: atom()
  def storage_field(attribute_name) do
    :"#{attribute_name}_translations"
  end

  @doc """
  Returns the all translations calculation name for an attribute.
  """
  @spec all_translations_field(atom()) :: atom()
  def all_translations_field(attribute_name) do
    :"#{attribute_name}_all_translations"
  end
end