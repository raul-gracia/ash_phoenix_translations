defmodule AshPhoenixTranslations.TranslationHistory do
  @moduledoc """
  Resource for tracking translation changes over time.

  This resource stores a history of all translation modifications,
  enabling audit trails, rollback capabilities, and tracking who made changes.
  """

  use Ash.Resource,
    # Compatible with multiple domains
    domain: nil,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id

    # Reference to the translated resource
    attribute :resource_id, :uuid do
      allow_nil? false
      description "ID of the resource this translation belongs to"
    end

    attribute :resource_type, :string do
      allow_nil? false
      description "Type/module name of the translated resource"
    end

    # Translation details
    attribute :attribute_name, :atom do
      allow_nil? false
      description "Name of the translated attribute"
    end

    attribute :locale, :atom do
      allow_nil? false
      description "Locale for this translation"
    end

    attribute :old_value, :string do
      allow_nil? true
      description "Previous translation value"
    end

    attribute :new_value, :string do
      allow_nil? false
      description "New translation value"
    end

    # Metadata
    attribute :translator_id, :uuid do
      allow_nil? true
      description "ID of the user who made this translation"
    end

    attribute :translator_email, :string do
      allow_nil? true
      description "Email of the translator"
    end

    attribute :change_reason, :string do
      allow_nil? true
      description "Optional reason for the translation change"
    end

    attribute :translated_at, :utc_datetime_usec do
      allow_nil? false
      default &DateTime.utc_now/0
      description "When this translation was made"
    end

    attribute :approved, :boolean do
      default false
      description "Whether this translation has been approved"
    end

    attribute :approved_by, :uuid do
      allow_nil? true
      description "ID of the user who approved this translation"
    end

    attribute :approved_at, :utc_datetime_usec do
      allow_nil? true
      description "When this translation was approved"
    end
  end

  actions do
    defaults [:create, :read]

    # Custom action for recording a translation change
    create :record_change do
      accept [
        :resource_id,
        :resource_type,
        :attribute_name,
        :locale,
        :old_value,
        :new_value,
        :translator_id,
        :translator_email,
        :change_reason
      ]
    end

    # Action for approving a translation
    update :approve do
      accept [:approved_by]

      change set_attribute(:approved, true)
      change set_attribute(:approved_at, &DateTime.utc_now/0)
    end

    # Action for rolling back to a previous translation
    read :find_previous do
      argument :resource_id, :uuid, allow_nil?: false
      argument :attribute_name, :atom, allow_nil?: false
      argument :locale, :atom, allow_nil?: false
      argument :before_date, :utc_datetime_usec, allow_nil?: false

      filter expr(
               resource_id == ^arg(:resource_id) and
                 attribute_name == ^arg(:attribute_name) and
                 locale == ^arg(:locale) and
                 translated_at < ^arg(:before_date)
             )

      prepare build(sort: [translated_at: :desc], limit: 1)
    end
  end

  calculations do
    # Calculate the age of the translation
    calculate :age_in_days, :integer do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          case record.translated_at do
            nil ->
              nil

            date ->
              DateTime.diff(DateTime.utc_now(), date, :day)
          end
        end)
      end
    end
  end

  # Identities are removed since ETS doesn't support native checking
  # In production with SQL backend, add:
  # identities do
  #   identity :unique_history_entry, 
  #            [:resource_id, :attribute_name, :locale, :translated_at]
  # end
end
