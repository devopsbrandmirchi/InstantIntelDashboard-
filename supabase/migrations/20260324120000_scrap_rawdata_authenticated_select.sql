-- Allow authenticated users to read scrap_rawdata (e.g. today counts on Client inventory sources).
-- service_role already had SELECT; this is for the dashboard using the anon JWT + login.

GRANT SELECT ON public.scrap_rawdata TO authenticated;
