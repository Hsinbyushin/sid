defmodule Sid.Planning do
  @moduledoc """
  Provides the acquisition-planning domain for SID.

  This context owns order plans and order lists. It intentionally does not know
  anything about vendor documents, catalogue providers, parsing, or acquisition
  follow-up. Those concerns belong to separate domain boundaries.
  """

  import Ecto.Query, warn: false

  alias Sid.Repo
  alias Sid.Planning.{OrderList, OrderPlan}

  @doc """
  Returns all order plans, newest first.
  """
  @spec list_order_plans() :: [OrderPlan.t()]
  def list_order_plans do
    OrderPlan
    |> order_by([plan], desc: plan.inserted_at)
    |> Repo.all()
  end

  @doc """
  Fetches an order plan by ID.

  Raises `Ecto.NoResultsError` when the plan does not exist.
  """
  @spec get_order_plan!(Ecto.UUID.t() | pos_integer()) :: OrderPlan.t()
  def get_order_plan!(id) do
    Repo.get!(OrderPlan, id)
  end

  @doc """
  Fetches an order plan together with its order lists.
  """
  @spec get_order_plan_with_lists!(Ecto.UUID.t() | pos_integer()) :: OrderPlan.t()
  def get_order_plan_with_lists!(id) do
    OrderPlan
    |> Repo.get!(id)
    |> Repo.preload(order_lists: from(list in OrderList, order_by: [asc: list.inserted_at]))
  end

  @doc """
  Creates an order plan.
  """
  @spec create_order_plan(map()) ::
          {:ok, OrderPlan.t()} | {:error, Ecto.Changeset.t()}
  def create_order_plan(attrs) do
    %OrderPlan{}
    |> OrderPlan.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates an order list belonging to the given order plan.

  Passing the plan struct rather than a raw plan ID keeps ownership explicit at
  the call site and reduces the risk of accidentally associating a list with
  an unrelated record.
  """
  @spec create_order_list(OrderPlan.t(), map()) ::
          {:ok, OrderList.t()} | {:error, Ecto.Changeset.t()}
  def create_order_list(%OrderPlan{} = order_plan, attrs \\ %{}) do
    %OrderList{order_plan_id: order_plan.id}
    |> OrderList.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns the order lists belonging to a given order plan.
  """
  @spec list_order_lists(OrderPlan.t()) :: [OrderList.t()]
  def list_order_lists(%OrderPlan{id: plan_id}) do
    OrderList
    |> where([list], list.order_plan_id == ^plan_id)
    |> order_by([list], asc: list.inserted_at)
    |> Repo.all()
  end

  @doc """
  Deletes an order plan.

  The database prevents deletion when order lists still reference the plan.
  This protects acquisition history from accidental cascading deletion.
  """
  @spec delete_order_plan(OrderPlan.t()) ::
          {:ok, OrderPlan.t()} | {:error, Ecto.Changeset.t()}
  def delete_order_plan(%OrderPlan{} = order_plan) do
    order_plan
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.foreign_key_constraint(
      :order_lists,
      name: :order_lists_order_plan_id_fkey,
      message: "cannot be deleted while order lists still belong to this plan"
    )
    |> Repo.delete()
  end
end
