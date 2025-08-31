defmodule AshPhoenixTranslations.Calculations.GettextTranslation do
  @moduledoc """
  Calculation for fetching translations from Gettext.
  
  This calculation uses Phoenix's Gettext module to retrieve translations
  based on the current locale and a message ID constructed from the
  resource name and attribute.
  """
  
  use Ash.Resource.Calculation
  
  @impl true
  def init(opts) do
    {:ok, opts}
  end
  
  @impl true
  def expression(opts, context) do
    # For Gettext, we need to return the value at runtime, not in expression
    # This is because Gettext translations are looked up dynamically
    nil
  end
  
  @impl true
  def calculate(records, opts, context) do
    attribute = opts[:attribute]
    resource_name = opts[:resource_name]
    gettext_module = opts[:gettext_module]
    locale = get_locale(context)
    
    # If no Gettext module is configured, fall back to the field value
    if is_nil(gettext_module) do
      Enum.map(records, fn record ->
        Map.get(record, attribute)
      end)
    else
      Enum.map(records, fn record ->
        # Construct the message ID from resource and attribute
        # e.g., "product.name", "product.description"
        msgid = "#{resource_name}.#{attribute}"
        
        # Get the default value from the record (usually English)
        default_value = Map.get(record, attribute) || ""
        
        # Try to get the translation from Gettext
        # If the translation doesn't exist, fall back to the default
        try do
          # Use Gettext.with_locale to set the locale for this translation
          Gettext.with_locale(gettext_module, to_string(locale), fn ->
            # Use dgettext for domain-based translations
            # The domain could be the resource name or a general "resources" domain
            Gettext.dgettext(gettext_module, "resources", msgid, %{
              default: default_value,
              # Pass the record ID for interpolation if needed
              id: record.id
            })
          end)
        rescue
          _ -> default_value
        end
      end)
    end
  end
  
  @impl true
  def load(_query, _opts, _context) do
    # Gettext translations don't need to load any fields
    []
  end
  
  @impl true
  def select(_query, opts, _context) do
    # We need the base attribute field for fallback
    [opts[:attribute]]
  end
  
  defp get_locale(context) do
    cond do
      # Check for locale in context (preferred)
      is_map(context) && Map.has_key?(context, :locale) ->
        context.locale
      
      # Check for locale in actor
      is_map(context) && is_map(context[:actor]) && Map.has_key?(context[:actor], :locale) ->
        context[:actor][:locale]
      
      # Check if Gettext has a current locale set
      Code.ensure_loaded?(Gettext) && function_exported?(Gettext, :get_locale, 0) ->
        String.to_atom(Gettext.get_locale())
      
      # Default to English
      true ->
        :en
    end
  end
end