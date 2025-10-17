defmodule AshPhoenixTranslations.ErrorSanitizer do
  @moduledoc """
  Sanitizes error messages to prevent information disclosure.

  SECURITY: VULN-007 - Information disclosure via error messages

  Ensures error messages exposed to users do not contain:
  - File paths
  - Stack traces
  - Database schema details
  - Internal implementation details
  - Sensitive configuration
  """

  require Logger

  @doc """
  Sanitizes an error for safe display to users.

  Returns a user-friendly error message while logging full details internally.
  """
  def sanitize_error(error, context \\ %{})

  def sanitize_error(%{__struct__: error_module} = error, context) when is_atom(error_module) do
    # Log full error internally
    log_error(error, context)

    # Detect error type from module name
    error_type = detect_error_type(error_module)

    case error_type do
      :validation_error ->
        %{
          type: :validation_error,
          message: "Validation failed. Please check your input.",
          field_errors: sanitize_field_errors(Map.get(error, :errors, []))
        }

      :authorization_error ->
        %{
          type: :authorization_error,
          message: "You do not have permission to perform this action."
        }

      :not_found ->
        %{
          type: :not_found,
          message: "The requested resource was not found."
        }

      _other ->
        %{
          type: :internal_error,
          message: "An error occurred while processing your request."
        }
    end
  end

  def sanitize_error({:error, %{message: message} = error}, context) when is_binary(message) do
    log_error(error, context)
    sanitize_generic_error(message)
  end

  def sanitize_error({:error, message}, context) when is_binary(message) do
    log_error(message, context)
    sanitize_generic_error(message)
  end

  def sanitize_error(error, context) do
    log_error(error, context)

    %{
      type: :internal_error,
      message: "An error occurred while processing your request."
    }
  end

  @doc """
  Sanitizes a changeset error for safe display.
  """
  def sanitize_changeset_error(%Ecto.Changeset{} = changeset) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        # Sanitize validation messages
        sanitize_validation_message(msg, opts)
      end)

    %{
      type: :validation_error,
      message: "Validation failed",
      errors: errors
    }
  end

  # Private functions

  defp detect_error_type(error_module) when is_atom(error_module) do
    module_name = Atom.to_string(error_module)

    cond do
      String.contains?(module_name, "Invalid") -> :validation_error
      String.contains?(module_name, "Validation") -> :validation_error
      String.contains?(module_name, "Forbidden") -> :authorization_error
      String.contains?(module_name, "Unauthorized") -> :authorization_error
      String.contains?(module_name, "NotFound") -> :not_found
      true -> :internal_error
    end
  end

  defp sanitize_field_errors(errors) when is_list(errors) do
    Enum.map(errors, &sanitize_field_error/1)
    |> Enum.reject(&is_nil/1)
  end

  defp sanitize_field_errors(_), do: []

  defp sanitize_field_error(%{field: field, message: message}) when is_atom(field) do
    %{
      field: field,
      message: sanitize_validation_message(message, [])
    }
  end

  defp sanitize_field_error(_), do: nil

  defp sanitize_validation_message(message, opts) when is_binary(message) do
    # Remove any file paths
    message = Regex.replace(~r{/[^\s]+\.(ex|exs|erl):\d+}, message, "[file]")

    # Remove function names that might expose implementation
    message = Regex.replace(~r{#Function<[^>]+>}, message, "[function]")

    # Remove module names that might expose implementation
    message =
      Regex.replace(
        ~r{Elixir\.[A-Z][A-Za-z0-9\.]+},
        message,
        fn full_match ->
          # Keep user-facing modules, hide internal ones
          if String.contains?(full_match, ["AshPhoenixTranslations", "Ash.", "Ecto."]) do
            "[module]"
          else
            full_match
          end
        end
      )

    # Interpolate safe option values
    safe_opts = sanitize_interpolation_opts(opts)
    interpolate_message(message, safe_opts)
  end

  defp sanitize_validation_message(message, _opts), do: inspect(message)

  defp sanitize_interpolation_opts(opts) when is_list(opts) do
    Enum.map(opts, fn
      {key, value} when is_number(value) or is_binary(value) or is_atom(value) ->
        {key, value}

      {key, _value} ->
        {key, "[redacted]"}
    end)
    |> Enum.into(%{})
  end

  defp sanitize_interpolation_opts(_), do: %{}

  defp interpolate_message(message, opts) do
    Enum.reduce(opts, message, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end

  defp sanitize_generic_error(message) when is_binary(message) do
    cond do
      # Database errors
      String.contains?(message, ["constraint", "unique", "foreign key", "check constraint"]) ->
        %{
          type: :validation_error,
          message: "A data constraint was violated. Please check your input."
        }

      # File system errors
      String.contains?(message, ["file", "directory", "permission denied", "ENOENT"]) ->
        %{
          type: :file_error,
          message: "Unable to access the requested file."
        }

      # Network errors
      String.contains?(message, ["timeout", "connection", "network"]) ->
        %{
          type: :network_error,
          message: "A network error occurred. Please try again."
        }

      # Generic fallback
      true ->
        %{
          type: :error,
          message: "An error occurred while processing your request."
        }
    end
  end

  defp log_error(error, context) do
    # Log full error with context for debugging
    stacktrace =
      case Process.info(self(), :current_stacktrace) do
        {:current_stacktrace, trace} when is_list(trace) ->
          Exception.format_stacktrace(trace)

        _ ->
          "(unavailable)"
      end

    Logger.error("Translation error occurred",
      error: inspect(error, pretty: true),
      context: inspect(context),
      stacktrace: stacktrace
    )
  end
end
