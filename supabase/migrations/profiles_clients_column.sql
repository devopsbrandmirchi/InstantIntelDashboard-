-- ============================================================
-- Ensure profiles has a 'clients' array for assigned client IDs.
-- Used by has_client(client_id) and User Management assign UI.
-- Run in: Supabase Dashboard → SQL Editor (if column missing).
-- ============================================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS clients BIGINT[] NOT NULL DEFAULT '{}';

COMMENT ON COLUMN public.profiles.clients IS 'Array of client IDs this user is assigned to (for has_client()).';
