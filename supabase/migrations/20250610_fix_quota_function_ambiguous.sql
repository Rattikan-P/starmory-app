-- Fix ambiguous column reference in get_user_quota_with_reset function
-- Add table alias to UPDATE statement to avoid ambiguity

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
BEGIN
  -- First, reset if needed (with table alias to avoid ambiguity)
  UPDATE public.user_quotas uq
  SET
    daily_gen_count = 0,
    daily_gen_reset_date = CURRENT_DATE,
    updated_at = NOW()
  WHERE uq.user_id = p_user_id
    AND (uq.daily_gen_reset_date IS NULL OR uq.daily_gen_reset_date < CURRENT_DATE);

  -- Then return the (possibly updated) quota
  RETURN QUERY
  SELECT
    uq.id,
    uq.user_id,
    uq.daily_gen_count,
    uq.daily_gen_reset_date,
    uq.total_gen_count,
    uq.created_at,
    uq.updated_at
  FROM public.user_quotas uq
  WHERE uq.user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-grant permission
GRANT EXECUTE ON FUNCTION public.get_user_quota_with_reset(UUID) TO authenticated;

COMMENT ON FUNCTION public.get_user_quota_with_reset(UUID) IS 'Get user quota with automatic daily reset. Use this function instead of direct SELECT to ensure daily_gen_count resets on new day.';
