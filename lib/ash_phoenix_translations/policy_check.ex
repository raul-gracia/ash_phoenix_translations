defmodule AshPhoenixTranslations.PolicyCheck do
  @moduledoc """
  Policy check module for translation access control.
  
  This module provides the actual policy check implementation
  that reads the persisted policy configuration and applies it.
  """

  use Ash.Policy.SimpleCheck

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
    
    case action.name do
      action_name when action_name in [:read, :get_translation] ->
        check_view_policy(actor, action, view_policy)
      
      action_name when action_name in [:update_translation, :import_translations, :clear_translations] ->
        check_edit_policy(actor, action, edit_policy)
      
      action_name when action_name in [:submit_translation, :approve_translation, :reject_translation] ->
        check_approval_policy(actor, action, approval_policy)
      
      _ ->
        # Default to allowing other actions
        true
    end
  end

  # Check view policies
  defp check_view_policy(_actor, _action, nil), do: true
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
    policy_module.authorized?(actor, action, action.resource)
  end

  # Check edit policies
  defp check_edit_policy(_actor, _action, nil), do: false
  
  defp check_edit_policy(actor, _action, :admin) do
    actor[:role] == :admin
  end
  
  defp check_edit_policy(actor, action, :translator) do
    if actor[:role] == :translator do
      locale = action.arguments[:locale]
      assigned_locales = actor[:assigned_locales] || []
      locale in assigned_locales
    else
      false
    end
  end
  
  defp check_edit_policy(actor, _action, {:role, roles}) do
    actor[:role] in roles
  end
  
  defp check_edit_policy(actor, action, {:custom, policy_module}) do
    policy_module.authorized?(actor, action, action.resource)
  end

  # Check approval policies
  defp check_approval_policy(_actor, _action, nil), do: false
  
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
end