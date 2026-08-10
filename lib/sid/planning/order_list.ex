defmodule Sid.Planning.OrderList do
  @moduledoc """
  Represents a concrete acquisition list within an order plan.

  Vendor imports will later be attached to order lists rather than directly
  to order plans. This preserves a clear hierarchy:

      OrderPlan
        -> OrderList
          -> future imports and acquisition selections

  The schema intentionally makes no assumptions about vendor file formats.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Sid.Planning.OrderPlan

  @type t :: %__MODULE__{}

  schema "order_lists" do
    field :name, :string

    belongs_to :order_plan, OrderPlan

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Builds a changeset for creating or updating an order list.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(order_list, attrs) do
    order_list
    |> cast(attrs, [:name, :order_plan_id])
    |> normalize_name()
    |> validate_required([:name, :order_plan_id])
    |> validate_length(:name, min: 1, max: 255)
    |> foreign_key_constraint(:order_plan_id)
    |> unique_constraint(
      [:order_plan_id, :name],
      name: :order_lists_order_plan_id_name_index,
      error_key: :name,
      message: "has already been used in this order plan"
    )
  end

  # Only surrounding whitespace is removed. We deliberately perform no
  # transliteration, case folding, or Unicode compatibility normalization
  # on user-facing names.
  defp normalize_name(changeset) do
    update_change(changeset, :name, &String.trim/1)
  end
end
