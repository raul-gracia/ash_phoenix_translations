defmodule AshPhoenixTranslations.LocaleValidator do
  @moduledoc """
  Secure locale and field validation to prevent atom exhaustion attacks.

  This module provides safe validation for user-provided locale codes and field names,
  ensuring that only valid, pre-defined atoms are created. This prevents denial-of-service
  attacks through atom table exhaustion.

  ## Security

  The BEAM VM has a fixed limit of approximately 1 million atoms. Creating atoms from
  untrusted user input can allow attackers to exhaust this limit and crash the VM.

  This module uses whitelisting and `String.to_existing_atom/1` to ensure:
  - Only supported locales can be converted to atoms
  - Only translatable fields can be converted to atoms
  - Invalid input is rejected with proper logging

  ## Configuration

  Configure supported locales in your application config:

      config :ash_phoenix_translations,
        supported_locales: [:en, :es, :fr, :de, :it, :pt, :ja, :zh, :ko, :ar, :ru]

  ## Examples

      # Valid locale
      iex> LocaleValidator.validate_locale("en")
      {:ok, :en}

      # Invalid locale
      iex> LocaleValidator.validate_locale("invalid")
      {:error, :invalid_locale}

      # Valid field for resource
      iex> LocaleValidator.validate_field("name", MyApp.Product)
      {:ok, :name}

      # Invalid field
      iex> LocaleValidator.validate_field("nonexistent", MyApp.Product)
      {:error, :invalid_field}
  """

  require Logger

  @default_locales ~w(en es fr de it pt ja zh ko ar ru)a

  @doc """
  Validates a locale and returns it as an atom if valid.

  Accepts both atoms and strings. For strings, validates against configured
  supported locales and only converts to existing atoms.

  ## Parameters

  - `locale` - The locale to validate (atom or string)

  ## Returns

  - `{:ok, locale_atom}` if valid
  - `{:error, :invalid_locale}` if invalid

  ## Examples

      validate_locale(:en)
      #=> {:ok, :en}

      validate_locale("es")
      #=> {:ok, :es}

      validate_locale("invalid")
      #=> {:error, :invalid_locale}

      validate_locale("<script>alert('xss')</script>")
      #=> {:error, :invalid_locale}
  """
  def validate_locale(locale) when is_atom(locale) do
    supported_locales = get_supported_locales()

    if locale in supported_locales do
      {:ok, locale}
    else
      log_rejection(:locale, locale, :not_supported)
      {:error, :invalid_locale}
    end
  end

  def validate_locale(locale) when is_binary(locale) do
    # First check for control characters or special characters (security check)
    if String.contains?(locale, ["\n", "\r", "\t", "\0", ";", "|", "&", "$", "`"]) do
      log_rejection(:locale, locale, :contains_special_characters)
      {:error, :invalid_locale}
    else
      # Sanitize input: trim whitespace and convert to lowercase
      sanitized = locale |> String.trim() |> String.downcase()

      # Validate format using regex pattern (basic locale codes)
      if not valid_locale_format?(sanitized) do
        log_rejection(:locale, locale, :invalid_format)
        {:error, :invalid_locale}
      else
        supported_locales = get_supported_locales()

        # Try to convert to existing atom only
        try do
          atom = String.to_existing_atom(sanitized)

          if atom in supported_locales do
            {:ok, atom}
          else
            log_rejection(:locale, locale, :not_supported)
            {:error, :invalid_locale}
          end
        rescue
          ArgumentError ->
            # Atom doesn't exist yet - check if it should be supported
            if sanitized in Enum.map(supported_locales, &to_string/1) do
              # The locale is configured but the atom doesn't exist yet.
              # This shouldn't happen in normal operation, but we log it
              Logger.warning(
                "Configured locale atom does not exist",
                locale: sanitized,
                hint: "Ensure locale atoms are created at compile time"
              )
            else
              log_rejection(:locale, locale, :not_existing_atom)
            end

            {:error, :invalid_locale}
        end
      end
    end
  end

  def validate_locale(_locale) do
    {:error, :invalid_locale}
  end

  @doc """
  Validates a field name against translatable attributes for a resource.

  ## Parameters

  - `field` - The field name to validate (atom or string)
  - `resource_module` - The Ash resource module to check against

  ## Returns

  - `{:ok, field_atom}` if valid
  - `{:error, :invalid_field}` if invalid

  ## Examples

      validate_field("name", MyApp.Product)
      #=> {:ok, :name}

      validate_field("nonexistent", MyApp.Product)
      #=> {:error, :invalid_field}
  """
  def validate_field(field, resource_module) when is_atom(field) do
    valid_fields = get_translatable_fields(resource_module)

    if field in valid_fields do
      {:ok, field}
    else
      log_rejection(:field, field, :not_translatable)
      {:error, :invalid_field}
    end
  end

  def validate_field(field, resource_module) when is_binary(field) do
    # Sanitize input
    sanitized = String.trim(field)

    valid_fields = get_translatable_fields(resource_module)

    # Try to convert to existing atom only
    try do
      atom = String.to_existing_atom(sanitized)

      if atom in valid_fields do
        {:ok, atom}
      else
        log_rejection(:field, field, :not_translatable)
        {:error, :invalid_field}
      end
    rescue
      ArgumentError ->
        log_rejection(:field, field, :not_existing_atom)
        {:error, :invalid_field}
    end
  end

  def validate_field(_field, _resource_module) do
    {:error, :invalid_field}
  end

  @doc """
  Returns the list of supported locales.

  Reads from application configuration, falling back to default locales.
  """
  def get_supported_locales do
    Application.get_env(:ash_phoenix_translations, :supported_locales, @default_locales)
  end

  # Private Functions

  defp valid_locale_format?(locale) when is_binary(locale) do
    # Match standard locale codes: 'en', 'es', 'en_US', 'zh_CN', etc.
    # This regex prevents injection attempts while allowing valid locale formats
    Regex.match?(~r/^[a-z]{2}(_[A-Z]{2})?$/, locale)
  end

  defp get_translatable_fields(resource_module) do
    try do
      resource_module
      |> AshPhoenixTranslations.Info.translatable_attributes()
      |> Enum.map(& &1.name)
    rescue
      _ ->
        # If resource doesn't use translations extension, return empty list
        []
    end
  end

  defp log_rejection(type, value, reason) do
    # Sanitize value for logging to prevent log injection
    sanitized_value =
      value
      |> inspect()
      |> String.slice(0, 100)

    Logger.warning("Translation input rejected",
      type: type,
      value: sanitized_value,
      reason: reason
    )
  end
end
