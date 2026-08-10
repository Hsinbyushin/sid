defmodule SidWeb.OrderPlanLive.Index do
  @moduledoc """
  LiveView for the acquisition-planning dashboard.

  This view intentionally focuses only on order plans and their budgets.
  Vendor imports, catalogue checks, and order-list contents belong to later
  development stages and separate domain boundaries.
  """

  use SidWeb, :live_view

  alias Sid.Planning
  alias Sid.Planning.OrderPlan

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "SID")
     |> assign(:order_plans, Planning.list_order_plans())
     |> assign(:form, empty_form())}
  end

  @impl true
  def handle_event("validate", %{"order_plan" => params}, socket) do
    changeset =
      %OrderPlan{}
      |> OrderPlan.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"order_plan" => params}, socket) do
    case Planning.create_order_plan(params) do
      {:ok, _order_plan} ->
        {:noreply,
         socket
         |> put_flash(:info, "Order plan created.")
         |> assign(:order_plans, Planning.list_order_plans())
         |> assign(:form, empty_form())}

      {:error, changeset} ->
        {:noreply,
         assign(
           socket,
           :form,
           to_form(Map.put(changeset, :action, :insert))
         )}
    end
  end

  defp format_money(amount, currency) do
    "#{Decimal.to_string(amount, :normal)} #{currency}"
  end

  defp empty_form do
    %OrderPlan{}
    |> OrderPlan.changeset(%{})
    |> to_form()
  end
end
