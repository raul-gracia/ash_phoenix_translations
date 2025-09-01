defmodule AshPhoenixTranslations.Transformers.SetupTranslationPolicies do
  @moduledoc """
  Sets up policy-based access control for translations.

  Adds policies for:
  - Viewing translations (per locale)
  - Editing translations (role-based)
  - Approval workflows for translation changes
  """

  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer

  @impl true
  def after?(AshPhoenixTranslations.Transformers.AddTranslationChanges), do: true
  def after?(_), do: false

  @impl true
  def transform(dsl_state) do
    # Get translation policy configuration
    policy_config = Transformer.get_option(dsl_state, [:translations], :policy)

    if policy_config && policy_config != false do
      with {:ok, dsl_state} <- ensure_policies_enabled(dsl_state),
           {:ok, dsl_state} <- setup_view_policies(dsl_state, policy_config),
           {:ok, dsl_state} <- setup_edit_policies(dsl_state, policy_config),
           {:ok, dsl_state} <- setup_approval_policies(dsl_state, policy_config) do
        {:ok, dsl_state}
      end
    else
      # No policies configured
      {:ok, dsl_state}
    end
  end

  defp ensure_policies_enabled(dsl_state) do
    # Check if authorize extension is already added
    extensions = Transformer.get_persisted(dsl_state, :extensions, [])

    if Ash.Policy.Authorizer in extensions do
      {:ok, dsl_state}
    else
      # Add the authorizer
      dsl_state =
        Transformer.persist(dsl_state, :extensions, [Ash.Policy.Authorizer | extensions])

      {:ok, dsl_state}
    end
  end

  defp setup_view_policies(dsl_state, policy_config) do
    view_policy = Keyword.get(policy_config, :view, :public)

    case view_policy do
      :public ->
        # Anyone can view translations
        add_public_view_policy(dsl_state)

      :authenticated ->
        # Only authenticated users can view
        add_authenticated_view_policy(dsl_state)

      {:locale, locale_config} ->
        # Per-locale viewing permissions
        add_locale_view_policies(dsl_state, locale_config)

      custom when is_atom(custom) ->
        # Custom policy module
        add_custom_view_policy(dsl_state, custom)

      _ ->
        {:ok, dsl_state}
    end
  end

  defp setup_edit_policies(dsl_state, policy_config) do
    edit_policy = Keyword.get(policy_config, :edit, :admin)

    case edit_policy do
      :admin ->
        # Only admins can edit
        add_admin_edit_policy(dsl_state)

      :translator ->
        # Translators can edit their assigned locales
        add_translator_edit_policy(dsl_state)

      {:role, roles} ->
        # Specific roles can edit
        add_role_edit_policies(dsl_state, roles)

      custom when is_atom(custom) ->
        # Custom policy module
        add_custom_edit_policy(dsl_state, custom)

      _ ->
        {:ok, dsl_state}
    end
  end

  defp setup_approval_policies(dsl_state, policy_config) do
    approval = Keyword.get(policy_config, :approval)

    if approval do
      # Add approval workflow policies
      add_approval_workflow_policies(dsl_state, approval)
    else
      {:ok, dsl_state}
    end
  end

  # Public view policy
  defp add_public_view_policy(dsl_state) do
    # For public access, we actually don't need to add a policy
    # The absence of a restrictive policy means public access
    {:ok, dsl_state}
  end

  # Authenticated view policy
  defp add_authenticated_view_policy(dsl_state) do
    # Build a simple policy check for authenticated users
    # Note: We can't use Ash.Policy.Check directly in transformers
    # Instead, we'll add a marker that the resource should check
    dsl_state =
      Transformer.persist(
        dsl_state,
        :translation_view_policy,
        :authenticated
      )

    {:ok, dsl_state}
  end

  # Per-locale view policies
  defp add_locale_view_policies(dsl_state, locale_config) do
    dsl_state =
      Transformer.persist(
        dsl_state,
        :translation_view_policy,
        {:locale, locale_config}
      )

    {:ok, dsl_state}
  end

  # Custom view policy
  defp add_custom_view_policy(dsl_state, policy_module) do
    dsl_state =
      Transformer.persist(
        dsl_state,
        :translation_view_policy,
        {:custom, policy_module}
      )

    {:ok, dsl_state}
  end

  # Admin edit policy
  defp add_admin_edit_policy(dsl_state) do
    dsl_state =
      Transformer.persist(
        dsl_state,
        :translation_edit_policy,
        :admin
      )

    {:ok, dsl_state}
  end

  # Translator edit policy
  defp add_translator_edit_policy(dsl_state) do
    dsl_state =
      Transformer.persist(
        dsl_state,
        :translation_edit_policy,
        :translator
      )

    {:ok, dsl_state}
  end

  # Role-based edit policies
  defp add_role_edit_policies(dsl_state, roles) do
    dsl_state =
      Transformer.persist(
        dsl_state,
        :translation_edit_policy,
        {:role, roles}
      )

    {:ok, dsl_state}
  end

  # Custom edit policy
  defp add_custom_edit_policy(dsl_state, policy_module) do
    dsl_state =
      Transformer.persist(
        dsl_state,
        :translation_edit_policy,
        {:custom, policy_module}
      )

    {:ok, dsl_state}
  end

  # Approval workflow policies
  defp add_approval_workflow_policies(dsl_state, approval_config) do
    dsl_state =
      Transformer.persist(
        dsl_state,
        :translation_approval_policy,
        approval_config
      )

    {:ok, dsl_state}
  end
end
