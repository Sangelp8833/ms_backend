defmodule MsBackendWeb.StatsController do
  use MsBackendWeb, :controller

  alias MsBackend.Orders

  # GET /api/admin/stats/sales?from=YYYY-MM-DD&to=YYYY-MM-DD
  def sales(conn, params) do
    from = parse_date(params["from"], default_from())
    to   = parse_date(params["to"],   DateTime.utc_now())

    data = Orders.sales_by_month(from, to)
    json(conn, %{data: data})
  end

  # GET /api/admin/stats/products?from=YYYY-MM-DD&to=YYYY-MM-DD&limit=10
  def top_products(conn, params) do
    from  = parse_date(params["from"], default_from())
    to    = parse_date(params["to"],   DateTime.utc_now())
    limit = parse_int(params["limit"], 10)

    data = Orders.top_products(from, to, limit)
    json(conn, %{data: data})
  end

  # GET /api/admin/stats/monthly
  def monthly(conn, _params) do
    stats = Orders.monthly_stats()
    json(conn, %{data: stats})
  end

  # ── helpers ───────────────────────────────────────────────────

  defp parse_date(nil, default), do: default
  defp parse_date(str, default) do
    case DateTime.from_iso8601(str <> "T00:00:00Z") do
      {:ok, dt, _} -> dt
      _ ->
        case DateTime.from_iso8601(str) do
          {:ok, dt, _} -> dt
          _            -> default
        end
    end
  end

  defp parse_int(nil, default), do: default
  defp parse_int(val, default) when is_integer(val), do: val
  defp parse_int(val, default) do
    case Integer.parse(to_string(val)) do
      {n, _} -> n
      :error -> default
    end
  end

  defp default_from do
    now = DateTime.utc_now()
    %{now | year: now.year - 1, month: now.month, day: 1,
            hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
  end
end
