-- Daily sales count (last 30 days) derived from saleprocessedvins.final_sold_date.

CREATE OR REPLACE FUNCTION public.get_sales_daily_count_30d()
RETURNS TABLE(customer_id bigint, sold_date date, sale_count bigint)
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT
    s.customer_id::bigint AS customer_id,
    s.final_sold_date::date AS sold_date,
    COUNT(*)::bigint AS sale_count
  FROM public.saleprocessedvins s
  WHERE s.customer_id IS NOT NULL
    AND s.final_sold_date IS NOT NULL
    AND s.final_sold_date::date >= (CURRENT_DATE - INTERVAL '29 days')::date
    AND s.final_sold_date::date <= CURRENT_DATE
  GROUP BY s.customer_id::bigint, s.final_sold_date::date
  ORDER BY sold_date DESC, customer_id;
$$;

COMMENT ON FUNCTION public.get_sales_daily_count_30d() IS 'Returns daily sales count per customer for last 30 days from saleprocessedvins.final_sold_date.';

GRANT EXECUTE ON FUNCTION public.get_sales_daily_count_30d() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_sales_daily_count_30d() TO service_role;
