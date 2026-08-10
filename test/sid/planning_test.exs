defmodule Sid.PlanningTest do
  use Sid.DataCase, async: true

  alias Sid.Planning
  alias Sid.Planning.{OrderList, OrderPlan}

  describe "order plans" do
    test "creates and retrieves an order plan" do
      attrs = %{
        name: "Myanmar Annual Order 2026",
        budget: Decimal.new("900.00"),
        base_currency: "EUR"
      }

      assert {:ok, %OrderPlan{} = created} =
               Planning.create_order_plan(attrs)

      retrieved = Planning.get_order_plan!(created.id)

      assert retrieved.id == created.id
      assert retrieved.name == "Myanmar Annual Order 2026"
      assert Decimal.equal?(retrieved.budget, Decimal.new("900.00"))
      assert retrieved.base_currency == "EUR"
    end

    test "persists an undefined budget as nil" do
      assert {:ok, plan} =
               Planning.create_order_plan(%{
                 name: "Budget Pending",
                 base_currency: "EUR"
               })

      retrieved = Planning.get_order_plan!(plan.id)

      assert retrieved.budget == nil
    end

    test "preserves multiscript text through a PostgreSQL round trip" do
      names = [
        "မြန်မာစာ စာအုပ်များ ၂၀၂၆",
        "中国年度订单 2027",
        "日本語資料 2026",
        "한국어 도서 주문 2026",
        "हिन्दी पुस्तक आदेश 2026",
        "বাংলা বই অর্ডার ২০২৬",
        "தமிழ் புத்தகங்கள் 2026",
        "తెలుగు పుస్తకాలు 2026",
        "ಕನ್ನಡ ಪುಸ್ತಕಗಳು 2026",
        "മലയാളം പുസ്തകങ്ങൾ 2026",
        "සිංහල පොත් 2026",
        "หนังสือภาษาไทย 2026",
        "ປຶ້ມພາສາລາວ 2026",
        "សៀវភៅខ្មែរ 2026",
        "བོད་ཡིག་དཔེ་ཆ་ 2026",
        "كتب عربية 2026",
        "بوكو جاوي 2026",
        "ᠮᠣᠩᠭᠣᠯ ᠨᠣᠮ 2026",
        "Қазақ кітаптары 2026",
        "Pāṇini — Aṣṭādhyāyī",
        "Viện Nghiên cứu Hán Nôm"
      ]

      Enum.each(names, fn name ->
        assert {:ok, plan} =
                 Planning.create_order_plan(%{
                   name: name,
                   base_currency: "EUR"
                 })

        assert Planning.get_order_plan!(plan.id).name == name
      end)
    end

    test "preserves decomposed combining characters through PostgreSQL" do
      name = "Pa\u0304n\u0323ini / Tie\u0302\u0301ng Vie\u0323\u0302t"

      assert {:ok, plan} =
               Planning.create_order_plan(%{
                 name: name,
                 base_currency: "EUR"
               })

      retrieved = Planning.get_order_plan!(plan.id)

      assert retrieved.name == name
    end

    test "lists order plans" do
      assert {:ok, first} =
               Planning.create_order_plan(%{
                 name: "Myanmar 2026",
                 base_currency: "EUR"
               })

      assert {:ok, second} =
               Planning.create_order_plan(%{
                 name: "China 2027",
                 base_currency: "EUR"
               })

      ids =
        Planning.list_order_plans()
        |> Enum.map(& &1.id)

      assert first.id in ids
      assert second.id in ids
    end

    test "deletes an order plan that has no order lists" do
      assert {:ok, plan} =
               Planning.create_order_plan(%{
                 name: "Temporary Plan",
                 base_currency: "EUR"
               })

      assert {:ok, deleted_plan} = Planning.delete_order_plan(plan)

      assert deleted_plan.id == plan.id

      assert_raise Ecto.NoResultsError, fn ->
        Planning.get_order_plan!(plan.id)
      end
    end
  end

  describe "order lists" do
    setup do
      {:ok, plan} =
        Planning.create_order_plan(%{
          name: "Myanmar Annual Order 2026",
          budget: Decimal.new("900.00"),
          base_currency: "EUR"
        })

      %{plan: plan}
    end

    test "creates an order list within a plan", %{plan: plan} do
      assert {:ok, %OrderList{} = order_list} =
               Planning.create_order_list(plan, %{
                 name: "Myanmar 2026-1"
               })

      assert order_list.order_plan_id == plan.id
      assert order_list.name == "Myanmar 2026-1"
    end

    test "lists only order lists belonging to the requested plan", %{plan: plan} do
      assert {:ok, other_plan} =
               Planning.create_order_plan(%{
                 name: "China Annual Order 2027",
                 base_currency: "EUR"
               })

      assert {:ok, first_list} =
               Planning.create_order_list(plan, %{name: "Myanmar 2026-1"})

      assert {:ok, second_list} =
               Planning.create_order_list(plan, %{name: "Myanmar 2026-2"})

      assert {:ok, _other_list} =
               Planning.create_order_list(other_plan, %{name: "China 2027-1"})

      ids =
        Planning.list_order_lists(plan)
        |> Enum.map(& &1.id)

      assert first_list.id in ids
      assert second_list.id in ids
      assert length(ids) == 2
    end

    test "rejects duplicate list names within the same plan", %{plan: plan} do
      assert {:ok, _first} =
               Planning.create_order_list(plan, %{name: "Myanmar 2026-1"})

      assert {:error, changeset} =
               Planning.create_order_list(plan, %{name: "Myanmar 2026-1"})

      assert {"has already been used in this order plan", _metadata} =
               Keyword.fetch!(changeset.errors, :name)
    end

    test "allows the same list name in different plans", %{plan: plan} do
      assert {:ok, other_plan} =
               Planning.create_order_plan(%{
                 name: "Myanmar Follow-up 2027",
                 base_currency: "EUR"
               })

      assert {:ok, _first} =
               Planning.create_order_list(plan, %{name: "Selection 1"})

      assert {:ok, _second} =
               Planning.create_order_list(other_plan, %{name: "Selection 1"})
    end

    test "retrieves a plan together with its lists", %{plan: plan} do
      assert {:ok, first} =
               Planning.create_order_list(plan, %{name: "Myanmar 2026-1"})

      assert {:ok, second} =
               Planning.create_order_list(plan, %{name: "Myanmar 2026-2"})

      loaded = Planning.get_order_plan_with_lists!(plan.id)

      ids = Enum.map(loaded.order_lists, & &1.id)

      assert first.id in ids
      assert second.id in ids
    end

    test "prevents deleting a plan that still contains order lists", %{plan: plan} do
      assert {:ok, _order_list} =
               Planning.create_order_list(plan, %{
                 name: "Myanmar 2026-1"
               })

      assert {:error, changeset} =
               Planning.delete_order_plan(plan)

      assert {
               "cannot be deleted while order lists still belong to this plan",
               _metadata
             } =
               Keyword.fetch!(changeset.errors, :order_lists)

      # The plan must still exist after the failed deletion attempt.
      assert Planning.get_order_plan!(plan.id).id == plan.id
    end
  end
end
