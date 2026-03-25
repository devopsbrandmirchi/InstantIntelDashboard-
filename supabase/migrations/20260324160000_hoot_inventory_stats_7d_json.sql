-- 7-day hoot inventory stats (JSON payload), only for clients with active_pull = true.

CREATE OR REPLACE FUNCTION public.get_hoot_inventory_stats_7d()
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
WITH bounds AS (
  SELECT
    (CURRENT_DATE - INTERVAL '6 days')::date AS range_start,
    CURRENT_DATE::date AS range_end
),
dates AS (
  SELECT generate_series(
    (SELECT range_start FROM bounds),
    (SELECT range_end FROM bounds),
    INTERVAL '1 day'
  )::date AS d
),
stats AS (
  SELECT
    c.dealership_name,
    h.pull_date::date AS stat_date,
    COUNT(*)::bigint AS row_count,
    COUNT(DISTINCT NULLIF(TRIM(h.vin), ''))::bigint AS distinct_vin_count
  FROM public.hoot_inventory h
  JOIN public.clients c ON c.id = h.customer_id
  WHERE h.pull_date BETWEEN (SELECT range_start FROM bounds) AND (SELECT range_end FROM bounds)
    AND COALESCE(c.is_active, false) = true
    AND COALESCE(c.active_pull, false) = true
  GROUP BY c.dealership_name, h.pull_date::date
)
SELECT jsonb_build_object(
  'range_start', (SELECT range_start FROM bounds),
  'range_end',   (SELECT range_end FROM bounds),
  'dates', (
    SELECT jsonb_agg(to_char(d, 'YYYY-MM-DD') ORDER BY d DESC)
    FROM dates
  ),
  'stats', (
    SELECT COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'dealership_name', s.dealership_name,
          'stat_date', to_char(s.stat_date, 'YYYY-MM-DD'),
          'row_count', s.row_count,
          'distinct_vin_count', s.distinct_vin_count
        )
        ORDER BY s.stat_date DESC, s.dealership_name
      ),
      '[]'::jsonb
    )
    FROM stats s
  )
);
$$;

GRANT EXECUTE ON FUNCTION public.get_hoot_inventory_stats_7d() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_hoot_inventory_stats_7d() TO service_role;
