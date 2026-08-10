defmodule Sid.Repo.Migrations.CreateOrderPlansAndOrderLists do
  use Ecto.Migration

  def change do
    create table(:order_plans) do
      # Human-readable name of the acquisition plan.
      # Names are stored as regular UTF-8 PostgreSQL text and must therefore
      # remain safe for multilingual and multiscript content.
      add :name, :string, null: false

      # Monetary values are stored as NUMERIC/Decimal, never as floating point.
      # A scale of 2 is appropriate for plan-level budgeting in the MVP.
      add :budget, :decimal, precision: 14, scale: 2, null: false

      # ISO 4217-style currency code such as EUR, USD, JPY, or MMK.
      # We deliberately use a string rather than a database enum so that
      # supporting an additional currency never requires a schema migration.
      add :base_currency, :string, size: 3, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create table(:order_lists) do
      # A concrete acquisition list belonging to a higher-level order plan.
      add :name, :string, null: false

      # Deleting a plan should not silently delete acquisition history.
      # We therefore use :restrict rather than cascading deletion.
      add :order_plan_id,
          references(:order_plans, on_delete: :restrict),
          null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:order_lists, [:order_plan_id])

    # List names should be unique within a plan, but the same descriptive
    # name may legitimately occur in different plans.
    create unique_index(
             :order_lists,
             [:order_plan_id, :name],
             name: :order_lists_order_plan_id_name_index
           )
  end
end
