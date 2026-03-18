-- 7 calendar days including today: row + distinct VIN counts per customer per pull_date
-- from normalized_inventory_from_scrap (same JSON shape as scrap feed stats for UI reuse).

CREATE OR REPLACE FUNCTION public.get_normalized_inventory_scrap_stats_7d()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_end   date := CURRENT_DATE;
  v_start date := CURRENT_DATE - 6;
BEGIN
  RETURN jsonb_build_object(
    'range_start', v_start::text,
    'range_end',   v_end::text,
    'dates', (
      SELECT COALESCE(
        jsonb_agg(to_char(s.d, 'YYYY-MM-DD') ORDER BY s.d DESC),
        '[]'::jsonb
      )
      FROM generate_series(v_start, v_end, interval '1 day') AS s(d)
    ),
    'stats', (
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'customer_id',        x.customer_id,
            'client_name',        x.client_name,
            'stat_date',          x.stat_date::text,
            'row_count',          x.row_count,
            'distinct_vin_count', x.distinct_vin_count
          )
        ),
        '[]'::jsonb
      )
      FROM (
        SELECT
          n.customer_id,
          COALESCE(MAX(c.full_name), 'Client #' || n.customer_id::text) AS client_name,
          n.pull_date::date AS stat_date,
          COUNT(*)::bigint AS row_count,
          COUNT(DISTINCT NULLIF(TRIM(COALESCE(n.vin, '')), ''))::bigint AS distinct_vin_count
        FROM public.normalized_inventory_from_scrap n
        LEFT JOIN public.clients c ON c.id = n.customer_id
        WHERE n.pull_date >= v_start
          AND n.pull_date <= v_end
          AND n.customer_id IS NOT NULL
        GROUP BY n.customer_id, n.pull_date::date
      ) x
    )
  );
END;
$$;

COMMENT ON FUNCTION public.get_normalized_inventory_scrap_stats_7d() IS
  '7 days incl. today: rows + distinct VINs per customer_id per pull_date from normalized_inventory_from_scrap. JSON { range_start, range_end, dates[], stats[] }.';

GRANT EXECUTE ON FUNCTION public.get_normalized_inventory_scrap_stats_7d() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_normalized_inventory_scrap_stats_7d() TO service_role;
