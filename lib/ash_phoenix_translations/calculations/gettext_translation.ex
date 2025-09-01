defmodule AshPhoenixTranslations.Calculations.GettextTranslation do
  @moduledoc """
  Calculation for retrieving translations from Gettext.
  """

  use Ash.Resource.Calculation
  
  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def calculate(records, opts, context) do
    field = opts[:field]
    locale = context[:locale] || :en
    gettext_module = opts[:gettext_module]

    unless gettext_module do
      raise ArgumentError, """
      Gettext module not configured. Please set the gettext_module option in your resource:
      
      translations do
        backend :gettext
        gettext_module MyAppWeb.Gettext
      end
      """
    end

    Enum.map(records, fn record ->
      get_gettext_translation(record, field, locale, gettext_module)
    end)
  end

  defp get_gettext_translation(record, field, locale, gettext_module) do
    # Build the msgid from resource name and field
    resource_name = record.__struct__
                    |> Module.split()
                    |> List.last()
                    |> Macro.underscore()
    
    # Get the record's unique identifier (could be id, slug, sku, etc.)
    identifier = get_record_identifier(record)
    
    # Build msgid like "product.name.laptop-001"
    msgid = "#{resource_name}.#{field}.#{identifier}"
    
    # Use Gettext with the specified module and locale
    old_locale = Gettext.get_locale(gettext_module)
    
    try do
      Gettext.put_locale(gettext_module, to_string(locale))
      
      # Try to get the translation, fall back to msgid if not found
      case apply(gettext_module, :dgettext, ["resources", msgid]) do
        ^msgid -> 
          # Translation not found, try fallback or return nil
          get_fallback_value(record, field, locale)
        translated -> 
          translated
      end
    after
      # Restore original locale
      Gettext.put_locale(gettext_module, old_locale)
    end
  rescue
    _error ->
      # If Gettext module doesn't exist or other error, fall back
      get_fallback_value(record, field, locale)
  end

  defp get_record_identifier(record) do
    cond do
      Map.has_key?(record, :slug) && record.slug -> record.slug
      Map.has_key?(record, :sku) && record.sku -> record.sku
      Map.has_key?(record, :id) && record.id -> to_string(record.id)
      true -> "unknown"
    end
  end

  defp get_fallback_value(record, field, locale) do
    # Try to get from database storage if available
    storage_field = :"#{field}_translations"
    
    if Map.has_key?(record, storage_field) do
      translations = Map.get(record, storage_field) || %{}
      Map.get(translations, to_string(locale))
    else
      nil
    end
  end
end