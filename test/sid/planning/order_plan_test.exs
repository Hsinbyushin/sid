defmodule Sid.Planning.OrderPlanTest do
  use ExUnit.Case, async: true

  alias Sid.Planning.OrderPlan

  describe "changeset/2" do
    test "accepts a valid order plan" do
      changeset =
        OrderPlan.changeset(%OrderPlan{}, %{
          name: "Myanmar Annual Order 2026",
          budget: Decimal.new("900.00"),
          base_currency: "EUR"
        })

      assert changeset.valid?
    end

    test "normalizes currency codes to uppercase" do
      changeset =
        OrderPlan.changeset(%OrderPlan{}, %{
          name: "Myanmar Annual Order 2026",
          budget: Decimal.new("900.00"),
          base_currency: "eur"
        })

      assert Ecto.Changeset.get_change(changeset, :base_currency) == "EUR"
    end

    test "rejects a negative budget" do
      changeset =
        OrderPlan.changeset(%OrderPlan{}, %{
          name: "Myanmar Annual Order 2026",
          budget: Decimal.new("-0.01"),
          base_currency: "EUR"
        })

      refute changeset.valid?

      assert {"must be greater than or equal to %{number}", _} =
               Keyword.fetch!(changeset.errors, :budget)
    end

    test "allows a zero budget" do
      changeset =
        OrderPlan.changeset(%OrderPlan{}, %{
          name: "Future Acquisition Plan",
          budget: Decimal.new("0.00"),
          base_currency: "EUR"
        })

      assert changeset.valid?
    end

    test "rejects structurally invalid currency codes" do
      changeset =
        OrderPlan.changeset(%OrderPlan{}, %{
          name: "Test Plan",
          budget: Decimal.new("100.00"),
          base_currency: "EURO"
        })

      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :base_currency)
    end

    test "preserves Myanmar script" do
      name = "မြန်မာစာ စာအုပ်များ ၂၀၂၆"

      changeset =
        OrderPlan.changeset(%OrderPlan{}, %{
          name: name,
          budget: Decimal.new("900.00"),
          base_currency: "EUR"
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :name) == name
    end

    test "preserves Chinese characters" do
      name = "中国年度订单 2027"

      changeset =
        OrderPlan.changeset(%OrderPlan{}, %{
          name: name,
          budget: Decimal.new("900.00"),
          base_currency: "EUR"
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :name) == name
    end

    test "preserves Tibetan script" do
      name = "བོད་ཡིག་དཔེ་ཆ་ 2026"

      changeset =
        OrderPlan.changeset(%OrderPlan{}, %{
          name: name,
          budget: Decimal.new("900.00"),
          base_currency: "EUR"
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :name) == name
    end

    test "trims surrounding whitespace without altering internal text" do
      changeset =
        OrderPlan.changeset(%OrderPlan{}, %{
          name: "  日本語資料 2026  ",
          budget: Decimal.new("900.00"),
          base_currency: "EUR"
        })

      assert Ecto.Changeset.get_change(changeset, :name) == "日本語資料 2026"
    end
  end

  test "preserves representative Unicode scripts without modification" do
    samples = [
      # Korean Hangul
      "한국어 도서 주문 2026",

      # Devanagari
      "हिन्दी पुस्तक आदेश 2026",

      # Bengali
      "বাংলা বই অর্ডার ২০২৬",

      # Tamil
      "தமிழ் புத்தகங்கள் 2026",

      # Telugu
      "తెలుగు పుస్తకాలు 2026",

      # Kannada
      "ಕನ್ನಡ ಪುಸ್ತಕಗಳು 2026",

      # Malayalam
      "മലയാളം പുസ്തകങ്ങൾ 2026",

      # Sinhala
      "සිංහල පොත් 2026",

      # Thai
      "หนังสือภาษาไทย 2026",

      # Lao
      "ປຶ້ມພາສາລາວ 2026",

      # Khmer
      "សៀវភៅខ្មែរ 2026",

      # Myanmar
      "မြန်မာစာ စာအုပ်များ ၂၀၂၆",

      # Tibetan
      "བོད་ཡིག་དཔེ་ཆ་ 2026",

      # Arabic
      "كتب عربية 2026",

      # Persian
      "کتاب‌های فارسی 2026",

      # Urdu
      "اردو کتابیں 2026",

      # Jawi / Malay in Arabic-derived script
      "بوكو جاوي 2026",

      # Hebrew
      "ספרים בעברית 2026",

      # Traditional Mongolian script
      "ᠮᠣᠩᠭᠣᠯ ᠨᠣᠮ 2026",

      # Mongolian Cyrillic
      "Монгол ном 2026",

      # Russian Cyrillic
      "Русские книги 2026",

      # Ukrainian Cyrillic
      "Українські книги 2026",

      # Belarusian Cyrillic
      "Беларускія кнігі 2026",

      # Bulgarian Cyrillic
      "Български книги 2026",

      # Serbian Cyrillic
      "Српске књиге 2026",

      # Macedonian Cyrillic
      "Македонски книги 2026",

      # Kazakh Cyrillic
      "Қазақ кітаптары 2026",

      # Kyrgyz Cyrillic
      "Кыргыз китептери 2026",

      # Tajik Cyrillic
      "Китобҳои тоҷикӣ 2026",

      # Uzbek Cyrillic
      "Ўзбек китоблари 2026",

      # Chinese
      "中国年度订单 2027",

      # Japanese
      "日本語資料 2026"
    ]

    Enum.each(samples, fn name ->
      changeset =
        OrderPlan.changeset(%OrderPlan{}, %{
          name: name,
          budget: Decimal.new("900.00"),
          base_currency: "EUR"
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :name) == name
    end)
  end

  test "preserves mixed right-to-left and left-to-right content" do
    name = "Jawi جاوي / العربية / فارسی / ISBN 978-1-2345-6789-0"

    changeset =
      OrderPlan.changeset(%OrderPlan{}, %{
        name: name,
        budget: Decimal.new("900.00"),
        base_currency: "EUR"
      })

    assert changeset.valid?
    assert Ecto.Changeset.get_change(changeset, :name) == name
  end

  test "preserves extended Latin characters and scholarly diacritics" do
    samples = [
      # German and common European diacritics
      "Ä Ö Ü ä ö ü ß À Á Â Ã Å Æ Ç È É Ê Ë Ì Í Î Ï Ñ Ò Ó Ô Õ Ø Œ Ù Ú Û Ý",

      # Central and Eastern European Latin alphabets
      "Ą Ć Č Ď Ę Ě Ł Ń Ň Ő Ř Ś Š Ť Ů Ű Ź Ż Ž",
      "ą ć č ď ę ě ł ń ň ő ř ś š ť ů ű ź ż ž",

      # Turkish and related Latin orthographies
      "Ç Ğ İ I Ö Ş Ü ç ğ ı i ö ş ü",

      # Baltic and Nordic characters
      "Ā Ē Ģ Ī Ķ Ļ Ņ Ū Ā Č Ę Ė Į Š Ų Ū Ž",
      "Æ Ø Å æ ø å",

      # Indic scholarly transliteration / IAST
      "ā ī ū ṛ ṝ ḷ ḹ ṅ ñ ṭ ḍ ṇ ś ṣ ṃ ḥ",
      "Ā Ī Ū Ṛ Ṝ Ḷ Ḹ Ṅ Ñ Ṭ Ḍ Ṇ Ś Ṣ Ṃ Ḥ",

      # Common Sanskrit/Pali transliteration samples
      "Śākyamuni",
      "Pāṇini",
      "Nāgārjuna",
      "Aṣṭādhyāyī",
      "Śrī Laṅkā",
      "saṃskṛta",
      "dharmaḥ",
      "ṭīkā",
      "ḍamaru",
      "Mahāyāna",
      "Theravāda",
      "Tipiṭaka",

      # Pali scholarly transliteration
      "Dīgha Nikāya",
      "Majjhima Nikāya",
      "Saṃyutta Nikāya",
      "Aṅguttara Nikāya",

      # Vietnamese lowercase vowels with tone marks
      "à á ả ã ạ",
      "ă ằ ắ ẳ ẵ ặ",
      "â ầ ấ ẩ ẫ ậ",
      "è é ẻ ẽ ẹ",
      "ê ề ế ể ễ ệ",
      "ì í ỉ ĩ ị",
      "ò ó ỏ õ ọ",
      "ô ồ ố ổ ỗ ộ",
      "ơ ờ ớ ở ỡ ợ",
      "ù ú ủ ũ ụ",
      "ư ừ ứ ử ữ ự",
      "ỳ ý ỷ ỹ ỵ",
      "đ",

      # Vietnamese uppercase equivalents
      "À Á Ả Ã Ạ",
      "Ă Ằ Ắ Ẳ Ẵ Ặ",
      "Â Ầ Ấ Ẩ Ẫ Ậ",
      "È É Ẻ Ẽ Ẹ",
      "Ê Ề Ế Ể Ễ Ệ",
      "Ì Í Ỉ Ĩ Ị",
      "Ò Ó Ỏ Õ Ọ",
      "Ô Ồ Ố Ổ Ỗ Ộ",
      "Ơ Ờ Ớ Ở Ỡ Ợ",
      "Ù Ú Ủ Ũ Ụ",
      "Ư Ừ Ứ Ử Ữ Ự",
      "Ỳ Ý Ỷ Ỹ Ỵ",
      "Đ",

      # Realistic Vietnamese text with stacked diacritics
      "Tiếng Việt",
      "Trường Đại học Quốc gia",
      "nghiên cứu Đông Nam Á",
      "Viện Nghiên cứu Hán Nôm",
      "Những quyển sách mới"
    ]

    Enum.each(samples, fn name ->
      changeset =
        OrderPlan.changeset(%OrderPlan{}, %{
          name: name,
          budget: Decimal.new("900.00"),
          base_currency: "EUR"
        })

      assert changeset.valid?,
             "expected changeset to accept and preserve: #{inspect(name)}"

      assert Ecto.Changeset.get_change(changeset, :name) == name
    end)
  end

  test "preserves decomposed combining diacritics without silently normalizing them" do
    samples = [
      # a + combining macron
      "a\u0304",

      # r + combining dot below
      "r\u0323",

      # t + combining dot below
      "t\u0323",

      # s + combining acute
      "s\u0301",

      # Vietnamese-style combinations:
      # a + circumflex + acute
      "a\u0302\u0301",

      # a + circumflex + grave
      "a\u0302\u0300",

      # a + breve + acute
      "a\u0306\u0301",

      # e + circumflex + tilde
      "e\u0302\u0303",

      # o + circumflex + dot below
      "o\u0302\u0323",

      # Mixed scholarly example
      "Pa\u0304n\u0323ini",

      # Mixed Vietnamese example
      "Tie\u0302\u0301ng Vie\u0323\u0302t"
    ]

    Enum.each(samples, fn name ->
      changeset =
        OrderPlan.changeset(%OrderPlan{}, %{
          name: name,
          budget: Decimal.new("900.00"),
          base_currency: "EUR"
        })

      assert changeset.valid?

      # This assertion is intentionally byte/codepoint-sensitive:
      # the domain layer must not silently apply NFC/NFD normalization.
      assert Ecto.Changeset.get_change(changeset, :name) == name
    end)
  end

  test "allows an order plan without a defined budget" do
    changeset =
      OrderPlan.changeset(%OrderPlan{}, %{
        name: "Myanmar Annual Order 2026",
        base_currency: "EUR"
      })

    assert changeset.valid?
    assert Ecto.Changeset.get_field(changeset, :budget) == nil
  end

  test "distinguishes an undefined budget from a zero budget" do
    undefined_budget =
      OrderPlan.changeset(%OrderPlan{}, %{
        name: "Budget Pending",
        base_currency: "EUR"
      })

    zero_budget =
      OrderPlan.changeset(%OrderPlan{}, %{
        name: "No Funds Available",
        budget: Decimal.new("0.00"),
        base_currency: "EUR"
      })

    assert undefined_budget.valid?
    assert zero_budget.valid?

    assert Ecto.Changeset.get_field(undefined_budget, :budget) == nil

    assert Decimal.equal?(
             Ecto.Changeset.get_field(zero_budget, :budget),
             Decimal.new("0.00")
           )
  end
end
