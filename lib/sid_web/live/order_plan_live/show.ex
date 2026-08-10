defmodule SidWeb.OrderPlanLive.Show do
  @moduledoc """
  LiveView for a single acquisition plan.

  The view presents the plan and its concrete order lists and allows new
  order lists to be created within the plan.

  Vendor imports, catalogue checks, and acquisition items are intentionally
  outside this view's current responsibility.
  """

  use SidWeb, :live_view

  alias Sid.Planning
  alias Sid.Planning.OrderList

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    order_plan = Planning.get_order_plan_with_lists!(id)

    {:ok,
     socket
     |> assign(:page_title, order_plan.name)
     |> assign(:order_plan, order_plan)
     |> assign(:form, empty_order_list_form(order_plan))}
  end

  @impl true
  def handle_event("validate", %{"order_list" => params}, socket) do
    changeset =
      %OrderList{order_plan_id: socket.assigns.order_plan.id}
      |> OrderList.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"order_list" => params}, socket) do
    order_plan = socket.assigns.order_plan

    case Planning.create_order_list(order_plan, params) do
      {:ok, _order_list} ->
        refreshed_order_plan =
          Planning.get_order_plan_with_lists!(order_plan.id)

        {:noreply,
         socket
         |> put_flash(:info, "Order list created.")
         |> assign(:order_plan, refreshed_order_plan)
         |> assign(:form, empty_order_list_form(refreshed_order_plan))}

      {:error, changeset} ->
        {:noreply,
         assign(
           socket,
           :form,
           to_form(Map.put(changeset, :action, :insert))
         )}
    end
  end

  defp empty_order_list_form(order_plan) do
    %OrderList{order_plan_id: order_plan.id}
    |> OrderList.changeset(%{})
    |> to_form()
  end
end
