defmodule AshPhoenixTranslations.Translations do
  @moduledoc """
  The translations DSL section for configuring translation behavior in Ash resources.
  """

  defstruct [
    :backend,
    :cache_ttl,
    :audit_changes,
    :auto_validate,
    :translatable_attributes
  ]

  @type t :: %__MODULE__{
          backend: :database | :gettext | :redis,
          cache_ttl: pos_integer(),
          audit_changes: boolean(),
          auto_validate: boolean(),
          translatable_attributes: [AshPhoenixTranslations.TranslatableAttribute.t()]
        }
end