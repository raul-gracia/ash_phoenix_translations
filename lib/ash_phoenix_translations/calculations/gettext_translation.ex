defmodule AshPhoenixTranslations.Calculations.GettextTranslation do
  @moduledoc """
  Calculation for fetching translations from Gettext.
  
  Uses the Gettext module to retrieve translations from PO files.
  """

  use Ash.Resource.Calculation

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def calculate(records, opts, context) do
    attribute_name = Keyword.fetch!(opts, :attribute_name)
    
    # Get the current locale from context
    locale = get_locale(context)
    
    # Get the Gettext module (should be configured)
    gettext_module = get_gettext_module()
    
    # Get translations for each record
    Enum.map(records, fn record ->
      # For Gettext, we need a message ID
      # This could be the original value or a constructed key
      message_id = build_message_id(record, attribute_name)
      
      # Use Gettext to get the translation
      if gettext_module && message_id do
        Gettext.with_locale(gettext_module, locale, fn ->
          Gettext.dgettext(gettext_module, "translations", message_id)
        end)
      else
        # Fallback to the original value if no Gettext module
        Map.get(record, attribute_name)
      end
    end)
  end

  @impl true
  def expression(_opts, _context) do
    # Gettext translations cannot be expressed as database queries
    # They must be loaded at runtime
    :runtime
  end

  defp get_locale(context) do
    # Try multiple sources for locale
    locale = 
      context[:locale] ||
      context[:query][:locale] ||
      Process.get(:locale) ||
      Gettext.get_locale() ||
      Application.get_env(:ash_phoenix_translations, :default_locale, :en)
    
    # Convert to string for Gettext
    to_string(locale)
  end

  defp get_gettext_module do
    # Get the configured Gettext module
    Application.get_env(:ash_phoenix_translations, :gettext_module)
  end

  defp build_message_id(record, attribute_name) do
    # Build a unique message ID for this translation
    # Format: "resource.attribute.id" or similar
    resource_name = record.__struct__ |> Module.split() |> List.last() |> Macro.underscore()
    
    if record.id do
      "#{resource_name}.#{attribute_name}.#{record.id}"
    else
      # For new records without ID, use the original value as message ID
      Map.get(record, attribute_name)
    end
  end
end