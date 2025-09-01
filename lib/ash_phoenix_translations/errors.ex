defmodule AshPhoenixTranslations.MissingTranslationError do
  @moduledoc """
  Error raised when a required translation is missing.
  """

  defexception [:locale, :available, :field, :resource]

  @impl true
  def message(exception) do
    available = Enum.map_join(exception.available, ", ", &inspect/1)

    """
    Missing translation for locale #{inspect(exception.locale)}.
    #{if exception.field, do: "Field: #{exception.field}", else: ""}
    #{if exception.resource, do: "Resource: #{exception.resource}", else: ""}
    Available locales: #{available}
    """
  end
end

defmodule AshPhoenixTranslations.InvalidLocaleError do
  @moduledoc """
  Error raised when an invalid locale is provided.
  """

  defexception [:locale, :supported]

  @impl true
  def message(exception) do
    supported = Enum.map_join(exception.supported, ", ", &inspect/1)

    """
    Invalid locale: #{inspect(exception.locale)}.
    Supported locales: #{supported}
    """
  end
end

defmodule AshPhoenixTranslations.BackendError do
  @moduledoc """
  Error raised when a backend operation fails.
  """

  defexception [:backend, :operation, :reason]

  @impl true
  def message(exception) do
    """
    Backend operation failed.
    Backend: #{exception.backend}
    Operation: #{exception.operation}
    Reason: #{inspect(exception.reason)}
    """
  end
end
