defmodule SidWeb.OrderPlanLive.ShowTest do
  use SidWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Sid.Planning

  describe "order plan detail page" do
    setup do
      {:ok, plan} =
        Planning.create_order_plan(%{
          name: "Myanmar Annual Order 2026",
          budget: Decimal.new("900.00"),
          base_currency: "EUR"
        })

      %{plan: plan}
    end

    test "renders the order plan and its budget", %{conn: conn, plan: plan} do
      {:ok, view, html} = live(conn, ~p"/plans/#{plan.id}")

      assert html =~ "Myanmar Annual Order 2026"
      assert html =~ "900"
      assert html =~ "EUR"
      assert html =~ "No order lists yet."

      assert has_element?(view, "#order-list-form")
    end

    test "renders an undefined budget explicitly", %{conn: conn} do
      {:ok, plan} =
        Planning.create_order_plan(%{
          name: "Budget Pending",
          base_currency: "EUR"
        })

      {:ok, _view, html} = live(conn, ~p"/plans/#{plan.id}")

      assert html =~ "Budget Pending"
      assert html =~ "Not defined"
    end

    test "creates an order list within the current plan", %{
      conn: conn,
      plan: plan
    } do
      {:ok, view, _html} = live(conn, ~p"/plans/#{plan.id}")

      view
      |> form("#order-list-form",
        order_list: %{
          name: "Myanmar 2026-1"
        }
      )
      |> render_submit()

      assert has_element?(
               view,
               "#order-lists",
               "Myanmar 2026-1"
             )

      [order_list] = Planning.list_order_lists(plan)

      assert order_list.name == "Myanmar 2026-1"
      assert order_list.order_plan_id == plan.id
    end

    test "creates multiple order lists within the same plan", %{
      conn: conn,
      plan: plan
    } do
      {:ok, view, _html} = live(conn, ~p"/plans/#{plan.id}")

      view
      |> form("#order-list-form",
        order_list: %{name: "Myanmar 2026-1"}
      )
      |> render_submit()

      view
      |> form("#order-list-form",
        order_list: %{name: "Myanmar 2026-2"}
      )
      |> render_submit()

      assert has_element?(view, "#order-lists", "Myanmar 2026-1")
      assert has_element?(view, "#order-lists", "Myanmar 2026-2")

      order_lists = Planning.list_order_lists(plan)

      assert length(order_lists) == 2
    end

    test "does not create an order list with an empty name", %{
      conn: conn,
      plan: plan
    } do
      {:ok, view, _html} = live(conn, ~p"/plans/#{plan.id}")

      html =
        view
        |> form("#order-list-form",
          order_list: %{name: ""}
        )
        |> render_submit()

      assert html =~ "can&#39;t be blank"
      assert Planning.list_order_lists(plan) == []
    end

    test "rejects duplicate order list names within the same plan", %{
      conn: conn,
      plan: plan
    } do
      {:ok, view, _html} = live(conn, ~p"/plans/#{plan.id}")

      view
      |> form("#order-list-form",
        order_list: %{name: "Myanmar 2026-1"}
      )
      |> render_submit()

      html =
        view
        |> form("#order-list-form",
          order_list: %{name: "Myanmar 2026-1"}
        )
        |> render_submit()

      assert html =~ "has already been used in this order plan"

      assert length(Planning.list_order_lists(plan)) == 1
    end

    test "keeps order lists isolated between different plans", %{
      conn: conn,
      plan: plan
    } do
      {:ok, other_plan} =
        Planning.create_order_plan(%{
          name: "China Annual Order 2027",
          budget: Decimal.new("1200.00"),
          base_currency: "EUR"
        })

      {:ok, _other_order_list} =
        Planning.create_order_list(other_plan, %{
          name: "China 2027-1"
        })

      {:ok, view, html} = live(conn, ~p"/plans/#{plan.id}")

      refute html =~ "China 2027-1"
      refute has_element?(view, "#order-lists", "China 2027-1")
    end

    test "preserves multiscript order list names through the complete round trip",
         %{conn: conn, plan: plan} do
      {:ok, view, _html} = live(conn, ~p"/plans/#{plan.id}")

      name =
        "Pāṇini / Tiếng Việt / မြန်မာစာ / 中文 / 한국어 / हिन्दी / العربية / جاوي / ᠮᠣᠩᠭᠣᠯ"

      view
      |> form("#order-list-form",
        order_list: %{name: name}
      )
      |> render_submit()

      assert has_element?(view, "#order-lists", name)

      [order_list] = Planning.list_order_lists(plan)

      assert order_list.name == name
    end

    test "preserves decomposed combining characters through the UI round trip",
         %{conn: conn, plan: plan} do
      {:ok, view, _html} = live(conn, ~p"/plans/#{plan.id}")

      # These strings deliberately contain decomposed Unicode sequences.
      # SID must preserve the submitted representation rather than silently
      # applying Unicode normalization in the domain or persistence layers.
      name = "Pa\u0304n\u0323ini / Tie\u0302\u0301ng Vie\u0323\u0302t"

      view
      |> form("#order-list-form",
        order_list: %{name: name}
      )
      |> render_submit()

      [order_list] = Planning.list_order_lists(plan)

      assert order_list.name == name
    end
  end
end
