-- ============================================================
-- Assign default role 'viewer' to every new user on signup
-- Run in: Supabase Dashboard → SQL Editor
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    viewer_role_id INT;
BEGIN
    -- 1. Create profile (unchanged)
    INSERT INTO public.profiles (id, email, full_name)
    VALUES (
        NEW.id,
        NEW.email,
        NEW.raw_user_meta_data->>'full_name'
    );

    -- 2. Assign default role 'viewer' in user_roles
    SELECT id INTO viewer_role_id
    FROM public.roles
    WHERE name = 'viewer'
    LIMIT 1;

    IF viewer_role_id IS NOT NULL THEN
        INSERT INTO public.user_roles (user_id, role_id)
        VALUES (NEW.id, viewer_role_id);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-create trigger (idempotent: drop if exists then create)
DROP TRIGGER IF EXISTS trg_on_auth_user_created ON auth.users;
CREATE TRIGGER trg_on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ============================================================
-- Optional: Backfill existing users who have no role
-- Run once if you already have users created before this migration
-- ============================================================
/*
INSERT INTO public.user_roles (user_id, role_id)
SELECT p.id, r.id
FROM public.profiles p
CROSS JOIN public.roles r
WHERE r.name = 'viewer'
  AND NOT EXISTS (
      SELECT 1 FROM public.user_roles ur WHERE ur.user_id = p.id
  );
*/
