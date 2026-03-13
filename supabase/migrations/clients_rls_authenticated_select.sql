-- ============================================================
-- Allow authenticated users to read the clients table.
-- Required for: Inventory Report client dropdown, Client Master list.
-- Run in: Supabase Dashboard → SQL Editor (if clients dropdown is blank).
-- ============================================================

ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "clients_select_authenticated" ON public.clients;
CREATE POLICY "clients_select_authenticated"
  ON public.clients FOR SELECT
  TO authenticated
  USING (true);

-- Allow authenticated users to update clients (e.g. active/inactive toggle)
DROP POLICY IF EXISTS "clients_update_authenticated" ON public.clients;
CREATE POLICY "clients_update_authenticated"
  ON public.clients FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Allow authenticated users to insert/delete (full Client Master CRUD)
DROP POLICY IF EXISTS "clients_insert_authenticated" ON public.clients;
CREATE POLICY "clients_insert_authenticated"
  ON public.clients FOR INSERT
  TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "clients_delete_authenticated" ON public.clients;
CREATE POLICY "clients_delete_authenticated"
  ON public.clients FOR DELETE
  TO authenticated
  USING (true);

-- Ensure authenticated role can select and modify
GRANT SELECT, INSERT, UPDATE, DELETE ON public.clients TO authenticated;
