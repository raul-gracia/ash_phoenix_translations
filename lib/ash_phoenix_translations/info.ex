defmodule AshPhoenixTranslations.Info do
  @moduledoc """
  Introspection module for AshPhoenixTranslations extension.

  Provides functions to retrieve translation configuration and metadata
  from resources that use the AshPhoenixTranslations extension.

  ## Examples

  Assuming you have a resource with translations configured:

      defmodule MyApp.Product do
        use Ash.Resource,
          extensions: [AshPhoenixTranslations]
        
        translations do
          translatable_attribute :name, locales: [:en, :es, :fr]
          translatable_attribute :description, locales: [:en, :es, :fr]
          backend :database
          cache_ttl 7200
        end
      end

  You can introspect the configuration:

      iex> AshPhoenixTranslations.Info.translatable?(MyApp.Product)
      true
      
      iex> AshPhoenixTranslations.Info.supported_locales(MyApp.Product)
      [:en, :es, :fr]
      
      iex> AshPhoenixTranslations.Info.backend(MyApp.Product)
      :database
      
      iex> AshPhoenixTranslations.Info.cache_ttl(MyApp.Product)
      7200
  """

  use Spark.InfoGenerator, extension: AshPhoenixTranslations, sections: [:translations]

  @doc """
  Returns all translatable attributes for a resource.
  """
  @spec translatable_attributes(Ash.Resource.t() | Spark.Dsl.t()) ::
          [AshPhoenixTranslations.TranslatableAttribute.t()]
  def translatable_attributes(resource) do
    # Try to get from persisted data first
    case Spark.Dsl.Extension.get_persisted(resource, :translatable_attributes) do
      {:ok, attrs} when is_list(attrs) ->
        attrs

      _ ->
        # Fallback to entities if not persisted
        case Spark.Dsl.Extension.get_entities(resource, [:translations]) do
          [] -> []
          entities -> entities
        end
    end
  end

  @doc """
  Returns the configured backend for translations.
  """
  @spec backend(Ash.Resource.t() | Spark.Dsl.t()) :: :database | :gettext
  def backend(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:translations], :backend, :database)
  end

  @doc """
  Returns the cache TTL in seconds.
  """
  @spec cache_ttl(Ash.Resource.t() | Spark.Dsl.t()) :: pos_integer()
  def cache_ttl(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:translations], :cache_ttl, 3600)
  end

  @doc """
  Returns whether translation changes should be audited.
  """
  @spec audit_changes?(Ash.Resource.t() | Spark.Dsl.t()) :: boolean()
  def audit_changes?(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:translations], :audit_changes, false)
  end

  @doc """
  Returns whether translations should be automatically validated.
  """
  @spec auto_validate?(Ash.Resource.t() | Spark.Dsl.t()) :: boolean()
  def auto_validate?(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:translations], :auto_validate, true)
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

  @doc """
  Get the translation policy configuration for a resource.
  """
  @spec translation_policies(Ash.Resource.t() | Spark.Dsl.t()) :: keyword() | nil
  def translation_policies(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:translations], :policy, nil)
  end

  @doc """
  Get the view policy for a resource.
  """
  @spec view_policy(Ash.Resource.t() | Spark.Dsl.t()) :: atom() | tuple() | nil
  def view_policy(resource) do
    case translation_policies(resource) do
      # Default to public view
      nil -> :public
      policies -> Keyword.get(policies, :view, :public)
    end
  end

  @doc """
  Get the edit policy for a resource.
  """
  @spec edit_policy(Ash.Resource.t() | Spark.Dsl.t()) :: atom() | tuple() | nil
  def edit_policy(resource) do
    case translation_policies(resource) do
      # Default to admin edit
      nil -> :admin
      policies -> Keyword.get(policies, :edit, :admin)
    end
  end

  @doc """
  Get the approval policy for a resource.
  """
  @spec approval_policy(Ash.Resource.t() | Spark.Dsl.t()) :: keyword() | nil
  def approval_policy(resource) do
    case translation_policies(resource) do
      nil -> nil
      policies -> Keyword.get(policies, :approval)
    end
  end
end
