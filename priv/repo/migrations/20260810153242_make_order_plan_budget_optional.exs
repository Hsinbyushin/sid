defmodule Sid.Repo.Migrations.MakeOrderPlanBudgetOptional do
  use Ecto.Migration

  def change do
    alter table(:order_plans) do
      # A missing budget means that no budget has been defined yet.
      # This is intentionally different from a budget of 0.00.
      modify :budget, :decimal,
        precision: 14,
        scale: 2,
        null: true,
        from: {:decimal, precision: 14, scale: 2, null: false}
    end
  end
end
