defmodule AshPhoenixTranslations.InputValidator do
  @moduledoc """
  Input validation for translation operations.

  SECURITY: VULN-011 - Lack of input length validation

  Prevents abuse through excessively long input that could:
  - Cause memory exhaustion
  - Overflow database columns
  - Slow down processing
  - Enable DoS attacks
  """

  require Logger

  # Maximum lengths for various input types
  # 10KB per translation
  @max_translation_length 10_000
  @max_field_name_length 100
  @max_resource_name_length 200
  @max_locale_code_length 10
  @max_key_length 500
  @max_metadata_length 1_000

  @doc """
  Validates a translation value.

  Returns `{:ok, value}` if valid, `{:error, reason}` otherwise.
  """
  def validate_translation(value) when is_binary(value) do
    cond do
      byte_size(value) > @max_translation_length ->
        {:error, :translation_too_long,
         "Translation exceeds maximum length of #{@max_translation_length} bytes"}

      String.valid?(value) ->
        {:ok, value}

      true ->
        {:error, :invalid_encoding, "Translation contains invalid UTF-8"}
    end
  end

  def validate_translation(nil), do: {:ok, nil}

  def validate_translation(_),
    do: {:error, :invalid_type, "Translation must be a string or nil"}

  @doc """
  Validates a field name.
  """
  def validate_field_name(field) when is_atom(field) do
    field_str = Atom.to_string(field)

    if byte_size(field_str) <= @max_field_name_length do
      {:ok, field}
    else
      {:error, :field_name_too_long,
       "Field name exceeds maximum length of #{@max_field_name_length}"}
    end
  end

  def validate_field_name(field) when is_binary(field) do
    cond do
      byte_size(field) > @max_field_name_length ->
        {:error, :field_name_too_long,
         "Field name exceeds maximum length of #{@max_field_name_length}"}

      not Regex.match?(~r/^[a-z][a-z0-9_]*$/, field) ->
        {:error, :invalid_field_name, "Field name contains invalid characters"}

      true ->
        {:ok, field}
    end
  end

  def validate_field_name(_), do: {:error, :invalid_type, "Field name must be a string or atom"}

  @doc """
  Validates a resource module name.
  """
  def validate_resource_name(resource) when is_atom(resource) do
    resource_str = Atom.to_string(resource)

    cond do
      byte_size(resource_str) > @max_resource_name_length ->
        {:error, :resource_name_too_long,
         "Resource name exceeds maximum length of #{@max_resource_name_length}"}

      not String.starts_with?(resource_str, "Elixir.") ->
        {:error, :invalid_resource, "Resource must be a valid module name"}

      true ->
        {:ok, resource}
    end
  end

  def validate_resource_name(resource) when is_binary(resource) do
    if byte_size(resource) <= @max_resource_name_length do
      {:ok, resource}
    else
      {:error, :resource_name_too_long,
       "Resource name exceeds maximum length of #{@max_resource_name_length}"}
    end
  end

  def validate_resource_name(_),
    do: {:error, :invalid_type, "Resource name must be a string or atom"}

  @doc """
  Validates a locale code.
  """
  def validate_locale_code(locale) when is_binary(locale) do
    cond do
      byte_size(locale) > @max_locale_code_length ->
        {:error, :locale_too_long,
         "Locale code exceeds maximum length of #{@max_locale_code_length}"}

      not Regex.match?(~r/^[a-z]{2}(_[A-Z]{2})?$/, locale) ->
        {:error, :invalid_locale_format, "Locale code must be in format 'en' or 'en_US'"}

      true ->
        {:ok, locale}
    end
  end

  def validate_locale_code(locale) when is_atom(locale) do
    locale
    |> Atom.to_string()
    |> validate_locale_code()
  end

  def validate_locale_code(_), do: {:error, :invalid_type, "Locale code must be a string or atom"}

  @doc """
  Validates a cache key component.
  """
  def validate_key_component(component) when is_binary(component) do
    if byte_size(component) <= @max_key_length do
      {:ok, component}
    else
      {:error, :key_component_too_long,
       "Key component exceeds maximum length of #{@max_key_length}"}
    end
  end

  def validate_key_component(component) when is_atom(component) or is_number(component) do
    component
    |> to_string()
    |> validate_key_component()
  end

  def validate_key_component(_),
    do: {:error, :invalid_type, "Key component must be a string, atom, or number"}

  @doc """
  Validates metadata (maps with string keys and values).
  """
  def validate_metadata(metadata) when is_map(metadata) do
    total_size =
      Enum.reduce(metadata, 0, fn {k, v}, acc ->
        acc + byte_size(to_string(k)) + byte_size(to_string(v))
      end)

    if total_size <= @max_metadata_length do
      {:ok, metadata}
    else
      {:error, :metadata_too_large,
       "Metadata exceeds maximum size of #{@max_metadata_length} bytes"}
    end
  end

  def validate_metadata(nil), do: {:ok, nil}

  def validate_metadata(_), do: {:error, :invalid_type, "Metadata must be a map"}

  @doc """
  Validates a batch of translations.

  Returns `{:ok, valid_translations}` with validated translations,
  or `{:error, invalid_count, errors}` if validation fails.
  """
  def validate_translation_batch(translations) when is_list(translations) do
    {valid, invalid} =
      Enum.reduce(translations, {[], []}, fn translation, {valid_acc, invalid_acc} ->
        case validate_translation_entry(translation) do
          {:ok, validated} -> {[validated | valid_acc], invalid_acc}
          {:error, reason} -> {valid_acc, [{translation, reason} | invalid_acc]}
        end
      end)

    if Enum.empty?(invalid) do
      {:ok, Enum.reverse(valid)}
    else
      Logger.warning("Translation batch validation failed",
        valid_count: length(valid),
        invalid_count: length(invalid)
      )

      {:error, length(invalid), Enum.reverse(invalid)}
    end
  end

  def validate_translation_batch(_),
    do: {:error, :invalid_type, "Translation batch must be a list"}

  # Private functions

  defp validate_translation_entry(%{field: field, locale: locale, value: value} = entry) do
    with {:ok, _} <- validate_field_name(field),
         {:ok, _} <- validate_locale_code(locale),
         {:ok, _} <- validate_translation(value) do
      {:ok, entry}
    else
      {:error, type, message} -> {:error, {type, message}}
      {:error, type} -> {:error, type}
    end
  end

  defp validate_translation_entry(entry) do
    {:error, {:invalid_entry, "Entry must have :field, :locale, and :value keys", entry}}
  end
end
