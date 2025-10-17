defmodule AshPhoenixTranslations.PolicyCheck do
  @moduledoc """
  Policy check module for translation access control.

  This module provides the actual policy check implementation
  that reads the persisted policy configuration and applies it.
  """

  use Ash.Policy.SimpleCheck
  require Logger
  alias AshPhoenixTranslations.AuditLogger

  @impl true
  def describe(_options) do
    "Checks translation access permissions"
  end

  @impl true
  def match?(actor, %{action: action} = _context, _options) do
    resource = action.resource

    # Get the policy configurations via the Info module
    view_policy = AshPhoenixTranslations.Info.view_policy(resource)
    edit_policy = AshPhoenixTranslations.Info.edit_policy(resource)
    approval_policy = AshPhoenixTranslations.Info.approval_policy(resource)

    result =
      case action.name do
        action_name when action_name in [:read, :get_translation] ->
          check_view_policy(actor, action, view_policy)

        action_name
        when action_name in [:update_translation, :import_translations, :clear_translations] ->
          check_edit_policy(actor, action, edit_policy)

        action_name
        when action_name in [:submit_translation, :approve_translation, :reject_translation] ->
          check_approval_policy(actor, action, approval_policy)

        _ ->
          # Default to allowing other actions
          true
      end

    # SECURITY: VULN-014 - Audit log all policy decisions
    AuditLogger.log_policy_decision(result, actor, action, resource)

    result
  end

  # Check view policies - SECURITY: Fail-closed for missing policies
  defp check_view_policy(_actor, _action, nil) do
    Logger.warning("Missing view policy configuration - denying access by default (fail-closed)")
    false
  end

  defp check_view_policy(_actor, _action, :public), do: true

  defp check_view_policy(actor, _action, :authenticated) do
    not is_nil(actor) && not is_nil(actor[:id])
  end

  defp check_view_policy(actor, action, {:locale, locale_config}) do
    locale = action.arguments[:locale]
    allowed_roles = locale_config[locale]

    if allowed_roles do
      actor[:role] in allowed_roles
    else
      true
    end
  end

  defp check_view_policy(actor, action, {:custom, policy_module}) do
    if valid_policy_module?(policy_module) do
      policy_module.authorized?(actor, action, action.resource)
    else
      Logger.error("Invalid or untrusted custom policy module - denying access",
        module: policy_module,
        resource: action.resource
      )

      false
    end
  end

  # Check edit policies - SECURITY: Fail-closed for missing policies
  defp check_edit_policy(_actor, _action, nil) do
    Logger.warning("Missing edit policy configuration - denying access by default (fail-closed)")
    false
  end

  defp check_edit_policy(actor, _action, :admin) do
    actor[:role] == :admin
  end

  defp check_edit_policy(actor, action, :translator) do
    # SECURITY: Strict validation for translator role
    with true <- is_map(actor),
         :translator <- actor[:role],
         locale when not is_nil(locale) <- action.arguments[:locale],
         assigned when is_list(assigned) <- actor[:assigned_locales],
         true <- locale in assigned do
      true
    else
      error ->
        Logger.warning("Translator edit authorization failed",
          actor_role: actor[:role],
          requested_locale: action.arguments[:locale],
          reason: inspect(error)
        )

        false
    end
  end

  defp check_edit_policy(actor, _action, {:role, roles}) do
    actor[:role] in roles
  end

  defp check_edit_policy(actor, action, {:custom, policy_module}) do
    if valid_policy_module?(policy_module) do
      policy_module.authorized?(actor, action, action.resource)
    else
      Logger.error("Invalid or untrusted custom policy module - denying access",
        module: policy_module,
        resource: action.resource
      )

      false
    end
  end

  # Check approval policies - SECURITY: Fail-closed for missing policies
  defp check_approval_policy(_actor, _action, nil) do
    Logger.warning(
      "Missing approval policy configuration - denying access by default (fail-closed)"
    )

    false
  end

  defp check_approval_policy(actor, action, approval_config) when is_list(approval_config) do
    case action.name do
      :submit_translation ->
        # Anyone can submit for approval
        true

      action_name when action_name in [:approve_translation, :reject_translation] ->
        # Check if actor is in approvers list
        approvers = Keyword.get(approval_config, :approvers, [:admin])
        actor[:role] in approvers

      _ ->
        false
    end
  end

  defp check_approval_policy(_actor, _action, _), do: false

  # SECURITY: Validate custom policy modules
  defp valid_policy_module?(module) do
    with true <- is_atom(module),
         true <- Code.ensure_loaded?(module),
         true <- function_exported?(module, :authorized?, 3),
         allowed <- get_allowed_policy_modules(),
         true <- module in allowed do
      true
    else
      _ -> false
    end
  end

  defp get_allowed_policy_modules do
    Application.get_env(:ash_phoenix_translations, :allowed_policy_modules, [])
  end
end
