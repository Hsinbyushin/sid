defmodule SidWeb.OrderPlanLive.IndexTest do
  use SidWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Sid.Planning

  describe "order plan dashboard" do
    test "renders the empty dashboard", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/")

      assert html =~ "Acquisition Planning"
      assert html =~ "No order plans yet."
      assert html =~ "New order plan"

      assert has_element?(
               view,
               "#order-plan-form"
             )
    end

    test "creates an order plan with a budget", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#order-plan-form",
        order_plan: %{
          name: "Myanmar Annual Order 2026",
          budget: "900.00",
          base_currency: "EUR"
        }
      )
      |> render_submit()

      assert render(view) =~ "Myanmar Annual Order 2026"
      assert render(view) =~ "900"
      assert render(view) =~ "EUR"

      [plan] = Planning.list_order_plans()

      assert plan.name == "Myanmar Annual Order 2026"
      assert Decimal.equal?(plan.budget, Decimal.new("900.00"))
      assert plan.base_currency == "EUR"
    end

    test "creates an order plan without a budget", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#order-plan-form",
        order_plan: %{
          name: "Budget Pending",
          budget: "",
          base_currency: "EUR"
        }
      )
      |> render_submit()

      assert render(view) =~ "Budget Pending"
      assert render(view) =~ "Not defined"

      [plan] = Planning.list_order_plans()

      assert plan.name == "Budget Pending"
      assert plan.budget == nil
    end

    test "distinguishes a zero budget from an undefined budget", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#order-plan-form",
        order_plan: %{
          name: "Zero Budget Plan",
          budget: "0.00",
          base_currency: "EUR"
        }
      )
      |> render_submit()

      html = render(view)

      assert html =~ "Zero Budget Plan"
      assert html =~ "0"
      refute html =~ "Not defined"

      [plan] = Planning.list_order_plans()

      assert Decimal.equal?(plan.budget, Decimal.new("0.00"))
    end

    test "normalizes the base currency entered by the user", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#order-plan-form",
        order_plan: %{
          name: "Currency Normalization",
          budget: "100.00",
          base_currency: "eur"
        }
      )
      |> render_submit()

      [plan] = Planning.list_order_plans()

      assert plan.base_currency == "EUR"
      assert render(view) =~ "EUR"
    end

    test "does not create an invalid order plan", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      html =
        view
        |> form("#order-plan-form",
          order_plan: %{
            name: "",
            budget: "-1.00",
            base_currency: "EURO"
          }
        )
        |> render_submit()

      assert html =~ "can&#39;t be blank"
      assert Planning.list_order_plans() == []
    end

    test "preserves multiscript input through the complete UI and database round trip",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      name =
        "Pāṇini / Tiếng Việt / မြန်မာစာ / 中文 / 한국어 / हिन्दी / العربية / جاوي / ᠮᠣᠩᠭᠣᠯ"

      view
      |> form("#order-plan-form",
        order_plan: %{
          name: name,
          budget: "500.00",
          base_currency: "EUR"
        }
      )
      |> render_submit()

      # The exact original string must survive the browser -> LiveView ->
      # changeset -> PostgreSQL -> LiveView -> HTML round trip.
      assert render(view) =~ name

      [plan] = Planning.list_order_plans()

      assert plan.name == name
    end
  end
end
