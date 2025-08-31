defmodule AshPhoenixTranslations.LiveView do
  @moduledoc """
  LiveView integration for AshPhoenixTranslations.
  
  Use this module in your LiveViews to add translation support:
  
      defmodule MyAppWeb.ProductLive do
        use MyAppWeb, :live_view
        use AshPhoenixTranslations.LiveView
        
        def mount(_params, session, socket) do
          socket = assign_locale(socket, session)
          {:ok, socket}
        end
        
        def handle_event("change_locale", %{"locale" => locale}, socket) do
          {:noreply, update_locale(socket, locale)}
        end
      end
  """

  import Phoenix.LiveView
  import Phoenix.Component

  @doc false
  defmacro __using__(_opts) do
    quote do
      import AshPhoenixTranslations.LiveView
      import AshPhoenixTranslations.Helpers
      
      on_mount {AshPhoenixTranslations.LiveView, :assign_locale}
    end
  end

  @doc """
  LiveView on_mount callback to assign locale from session.
  
  Can be used in router:
  
      live_session :default, on_mount: {AshPhoenixTranslations.LiveView, :assign_locale} do
        # your live routes
      end
  """
  def on_mount(:assign_locale, _params, session, socket) do
    locale = session["locale"] || "en"
    
    socket =
      socket
      |> assign(:locale, locale)
      |> attach_locale_hook()
    
    {:cont, socket}
  end

  @doc """
  Assigns locale to the socket from session or params.
  
      def mount(params, session, socket) do
        socket = assign_locale(socket, session, params)
        {:ok, socket}
      end
  """
  def assign_locale(socket, session, params \\ %{}) do
    locale = params["locale"] || session["locale"] || "en"
    
    socket
    |> assign(:locale, locale)
    |> attach_locale_hook()
  end

  @doc """
  Updates the locale in the socket and broadcasts the change.
  
      def handle_event("change_locale", %{"locale" => locale}, socket) do
        {:noreply, update_locale(socket, locale)}
      end
  """
  def update_locale(socket, locale) do
    socket
    |> assign(:locale, locale)
    |> push_event("locale_changed", %{locale: locale})
    |> put_locale_in_session(locale)
  end

  @doc """
  Assigns translated resources to the socket.
  
      def mount(_params, session, socket) do
        socket = 
          socket
          |> assign_locale(session)
          |> assign_translations(:products, Products.list_products!())
        
        {:ok, socket}
      end
  """
  def assign_translations(socket, key, resources) when is_list(resources) do
    locale = socket.assigns[:locale] || "en"
    translated = Enum.map(resources, &translate_resource(&1, locale))
    assign(socket, key, translated)
  end

  def assign_translations(socket, key, resource) do
    locale = socket.assigns[:locale] || "en"
    translated = translate_resource(resource, locale)
    assign(socket, key, translated)
  end

  @doc """
  Handles locale change from a form or select component.
  
      def handle_event("locale_form_change", %{"locale" => locale}, socket) do
        {:noreply, handle_locale_change(socket, locale)}
      end
  """
  def handle_locale_change(socket, locale) do
    socket
    |> update_locale(locale)
    |> reload_translations()
  end

  @doc """
  Reloads all translated assigns in the socket.
  
      socket = reload_translations(socket)
  """
  def reload_translations(socket) do
    locale = socket.assigns[:locale] || "en"
    
    Enum.reduce(socket.assigns, socket, fn
      {key, %{__struct__: _} = resource}, socket ->
        if translatable?(resource) do
          assign(socket, key, translate_resource(resource, locale))
        else
          socket
        end
      
      {key, resources}, socket when is_list(resources) ->
        if Enum.any?(resources, &translatable?/1) do
          translated = Enum.map(resources, &translate_resource(&1, locale))
          assign(socket, key, translated)
        else
          socket
        end
      
      _, socket ->
        socket
    end)
  end

  @doc """
  Creates a locale switcher component for LiveView.
  
      <.locale_switcher socket={@socket} />
      <.locale_switcher socket={@socket} class="custom-class" />
  """
  attr :socket, :map, required: true
  attr :class, :string, default: "locale-switcher"
  attr :locales, :list, default: nil

  def locale_switcher(assigns) do
    assigns = 
      assigns
      |> assign_new(:locales, fn -> default_locales() end)
      |> assign_new(:current_locale, fn -> assigns.socket.assigns[:locale] || "en" end)

    ~H"""
    <div class={@class}>
      <select phx-change="change_locale" name="locale">
        <%= for locale <- @locales do %>
          <option value={locale} selected={locale == @current_locale}>
            <%= locale_name(locale) %>
          </option>
        <% end %>
      </select>
    </div>
    """
  end

  @doc """
  Translation input component for LiveView forms.
  
      <.translation_field form={@form} field={:name} locales={[:en, :es, :fr]} />
  """
  attr :form, :map, required: true
  attr :field, :atom, required: true
  attr :locales, :list, default: [:en, :es, :fr]
  attr :type, :string, default: "text"
  attr :label, :string, default: nil
  attr :class, :string, default: "translation-field"

  def translation_field(assigns) do
    assigns = assign_new(assigns, :label, fn -> 
      humanize(assigns.field) 
    end)

    ~H"""
    <div class={@class}>
      <label><%= @label %></label>
      <%= for locale <- @locales do %>
        <div class="translation-input">
          <label for={"#{@field}_#{locale}"}>
            <%= locale_name(locale) %>
          </label>
          <%= if @type == "textarea" do %>
            <textarea
              id={"#{@field}_#{locale}"}
              name={"#{@form.name}[#{@field}_translations][#{locale}]"}
              phx-debounce="300"
            ><%= get_translation_value(@form, @field, locale) %></textarea>
          <% else %>
            <input
              type={@type}
              id={"#{@field}_#{locale}"}
              name={"#{@form.name}[#{@field}_translations][#{locale}]"}
              value={get_translation_value(@form, @field, locale)}
              phx-debounce="300"
            />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Shows translation completeness progress bar.
  
      <.translation_progress resource={@product} />
  """
  attr :resource, :map, required: true
  attr :fields, :list, default: nil
  attr :locales, :list, default: [:en, :es, :fr]
  attr :class, :string, default: "translation-progress"

  def translation_progress(assigns) do
    assigns = 
      assigns
      |> assign(:percentage, calculate_completeness(assigns.resource, assigns.fields, assigns.locales))

    ~H"""
    <div class={@class}>
      <div class="progress-bar">
        <div class="progress-fill" style={"width: #{@percentage}%"}>
          <%= @percentage %>%
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Live translation preview component.
  
      <.translation_preview resource={@product} field={:description} />
  """
  attr :resource, :map, required: true
  attr :field, :atom, required: true
  attr :locales, :list, default: [:en, :es, :fr]
  attr :class, :string, default: "translation-preview"

  def translation_preview(assigns) do
    ~H"""
    <div class={@class}>
      <div class="tabs">
        <%= for locale <- @locales do %>
          <button
            class={"tab #{if @socket.assigns[:preview_locale] == locale, do: "active"}"}
            phx-click="set_preview_locale"
            phx-value-locale={locale}
          >
            <%= locale_name(locale) %>
          </button>
        <% end %>
      </div>
      <div class="preview-content">
        <%= translate_field(@resource, @field, @socket.assigns[:preview_locale] || :en) %>
      </div>
    </div>
    """
  end

  @doc """
  Subscribes to translation updates for real-time synchronization.
  
      def mount(_params, _session, socket) do
        if connected?(socket) do
          subscribe_to_translations(Product)
        end
        {:ok, socket}
      end
  """
  def subscribe_to_translations(resource_module) do
    Phoenix.PubSub.subscribe(
      pubsub_server(),
      "translations:#{resource_module}"
    )
  end

  @doc """
  Broadcasts translation updates to subscribed LiveViews.
  
      broadcast_translation_update(product, :name, :es, "Producto")
  """
  def broadcast_translation_update(resource, field, locale, value) do
    Phoenix.PubSub.broadcast(
      pubsub_server(),
      "translations:#{resource.__struct__}",
      {:translation_updated, resource.id, field, locale, value}
    )
  end

  @doc """
  Handles translation update broadcasts.
  
      def handle_info({:translation_updated, id, field, locale, value}, socket) do
        socket = handle_translation_update(socket, id, field, locale, value)
        {:noreply, socket}
      end
  """
  def handle_translation_update(socket, resource_id, field, locale, value) do
    # Update the resource if it's in the socket assigns
    Enum.reduce(socket.assigns, socket, fn
      {key, %{id: ^resource_id} = resource}, socket ->
        updated = update_translation_in_resource(resource, field, locale, value)
        assign(socket, key, updated)
      
      {key, resources}, socket when is_list(resources) ->
        updated = Enum.map(resources, fn
          %{id: ^resource_id} = resource ->
            update_translation_in_resource(resource, field, locale, value)
          other ->
            other
        end)
        assign(socket, key, updated)
      
      _, socket ->
        socket
    end)
  end

  # Private helpers

  defp attach_locale_hook(socket) do
    attach_hook(socket, :locale_params, :handle_params, fn
      params, _uri, socket ->
        if params["locale"] && params["locale"] != socket.assigns[:locale] do
          {:cont, update_locale(socket, params["locale"])}
        else
          {:cont, socket}
        end
    end)
  end

  defp put_locale_in_session(socket, locale) do
    # This would need to be implemented based on your session handling
    # For now, we'll store it in socket assigns
    socket
  end

  defp translate_resource(resource, locale) do
    AshPhoenixTranslations.translate(resource, locale)
  end

  defp translatable?(%{__struct__: module}) do
    AshPhoenixTranslations.Info.translatable?(module)
  rescue
    _ -> false
  end
  defp translatable?(_), do: false

  defp default_locales do
    ["en", "es", "fr", "de", "it", "pt", "ja", "zh", "ko", "ar", "ru"]
  end

  defp locale_name(locale) do
    AshPhoenixTranslations.Helpers.locale_name(locale)
  end

  defp humanize(field) do
    field
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp get_translation_value(form, field, locale) do
    storage_field = :"#{field}_translations"
    
    case form.data do
      %{^storage_field => translations} when is_map(translations) ->
        Map.get(translations, locale) || Map.get(translations, to_string(locale))
      _ ->
        nil
    end
  end

  defp calculate_completeness(resource, fields, locales) do
    fields = fields || translatable_fields(resource)
    
    total = length(fields) * length(locales)
    
    completed = 
      Enum.reduce(fields, 0, fn field, acc ->
        storage_field = :"#{field}_translations"
        translations = Map.get(resource, storage_field, %{})
        
        count = 
          Enum.count(locales, fn locale ->
            translation = Map.get(translations, locale)
            translation && translation != ""
          end)
        
        acc + count
      end)
    
    if total > 0 do
      round(completed / total * 100)
    else
      0
    end
  end

  defp translatable_fields(resource) do
    resource.__struct__
    |> AshPhoenixTranslations.Info.translatable_attributes()
    |> Enum.map(& &1.name)
  rescue
    _ -> []
  end

  defp update_translation_in_resource(resource, field, locale, value) do
    storage_field = :"#{field}_translations"
    current_translations = Map.get(resource, storage_field, %{})
    updated_translations = Map.put(current_translations, locale, value)
    Map.put(resource, storage_field, updated_translations)
  end

  defp pubsub_server do
    # This should be configured per application
    Application.get_env(:ash_phoenix_translations, :pubsub_server) ||
      MyApp.PubSub
  end

  defp translate_field(resource, field, locale) do
    AshPhoenixTranslations.Helpers.translate_field(resource, field, locale)
  end
end