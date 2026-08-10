defmodule Sid.Planning.OrderPlan do
  @moduledoc """
  Represents a high-level acquisition plan.

  An order plan groups one or more concrete order lists under a shared
  acquisition purpose and budget.

  Examples include:

      "Myanmar Annual Order 2026"
      "Chinese Studies 2027"
      "South Asia Antiquarian Purchases"

  The schema deliberately contains no vendor-, catalogue-, or document-specific
  fields. Those concerns belong to separate SID domain boundaries.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Sid.Planning.OrderList

  @type t :: %__MODULE__{}

  schema "order_plans" do
    field :name, :string
    field :budget, :decimal
    field :base_currency, :string

    has_many :order_lists, OrderList

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Builds a changeset for creating or updating an order plan.

  Currency values are normalized to uppercase before validation.

  At this stage SID validates the structural form of an ISO 4217 currency code
  (three ASCII letters). Semantic validation against the complete ISO currency
  registry will be introduced separately rather than embedding a potentially
  stale currency list in the domain schema.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(order_plan, attrs) do
    order_plan
    |> cast(attrs, [:name, :budget, :base_currency])
    |> normalize_name()
    |> normalize_currency()
    |> validate_required([:name, :base_currency])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_number(:budget, greater_than_or_equal_to: 0)
    |> validate_format(
      :base_currency,
      ~r/^[A-Z]{3}$/,
      message: "must be a three-letter uppercase currency code"
    )
  end

  # Trimming surrounding whitespace is safe for a plan name while preserving
  # the original Unicode content inside the string.
  defp normalize_name(changeset) do
    update_change(changeset, :name, &String.trim/1)
  end

  # Currency identifiers are case-insensitive input but canonical uppercase
  # values simplify comparisons and future currency conversion logic.
  defp normalize_currency(changeset) do
    update_change(changeset, :base_currency, fn currency ->
      currency
      |> String.trim()
      |> String.upcase()
    end)
  end
end
