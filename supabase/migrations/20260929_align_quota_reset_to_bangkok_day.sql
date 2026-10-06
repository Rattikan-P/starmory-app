-- Keep daily quota reset dates aligned with the Bangkok calendar used by the app.
CREATE OR REPLACE FUNCTION public.auto_reset_daily_quota()
RETURNS TRIGGER AS $$
DECLARE
  today_date DATE := (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Bangkok')::DATE;
BEGIN
  IF OLD.daily_gen_reset_date IS NULL OR OLD.daily_gen_reset_date < today_date THEN
    NEW.daily_gen_count := COALESCE(NEW.daily_gen_count, 0);
    NEW.daily_gen_reset_date := today_date;
  END IF;

  IF NEW.daily_gen_reset_date IS NULL OR NEW.daily_gen_reset_date < today_date THEN
    NEW.daily_gen_reset_date := today_date;
    NEW.daily_gen_count := 0;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.get_user_quota_with_reset(p_user_id UUID)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  daily_gen_count INTEGER,
  daily_gen_reset_date DATE,
  total_gen_count INTEGER,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
DECLARE
  today_date DATE := (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Bangkok')::DATE;
BEGIN
  UPDATE public.user_quotas AS uq
  SET
    daily_gen_count = 0,
    daily_gen_reset_date = today_date,
    updated_at = NOW()
  WHERE uq.user_id = p_user_id
    AND (uq.daily_gen_reset_date IS NULL OR uq.daily_gen_reset_date < today_date);

  RETURN QUERY
  SELECT
    uq.id,
    uq.user_id,
    uq.daily_gen_count,
    uq.daily_gen_reset_date,
    uq.total_gen_count,
    uq.created_at,
    uq.updated_at
  FROM public.user_quotas AS uq
  WHERE uq.user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_user_quota_with_reset(UUID) TO authenticated;

COMMENT ON FUNCTION public.get_user_quota_with_reset(UUID) IS
  'Get user quota with automatic reset at the start of a new Bangkok calendar day.';
