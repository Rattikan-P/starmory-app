-- Migration: Auto-reset daily quota on access
-- This ensures daily_gen_count resets to 0 when a new day starts

-- Create function that auto-resets before any update operation
CREATE OR REPLACE FUNCTION public.auto_reset_daily_quota()
RETURNS TRIGGER AS $$
BEGIN
  -- If the reset date is not today, reset the daily count
  IF (OLD.daily_gen_reset_date IS NULL OR OLD.daily_gen_reset_date < CURRENT_DATE) THEN
    NEW.daily_gen_count := COALESCE(NEW.daily_gen_count, 0);
    NEW.daily_gen_reset_date := CURRENT_DATE;
  END IF;

  -- If explicitly updating daily_gen_count but reset date is old, also update reset date
  IF (NEW.daily_gen_reset_date < CURRENT_DATE) THEN
    NEW.daily_gen_reset_date := CURRENT_DATE;
    NEW.daily_gen_count := COALESCE(NEW.daily_gen_count, 0);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger that fires before any update
DROP TRIGGER IF EXISTS trigger_auto_reset_daily_quota ON public.user_quotas;
CREATE TRIGGER trigger_auto_reset_daily_quota
  BEFORE UPDATE ON public.user_quotas
  FOR EACH ROW
  EXECUTE FUNCTION public.auto_reset_daily_quota();

-- Function to get quota with auto-reset (wrap SELECT with reset logic)
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
  -- First, reset if needed
  UPDATE public.user_quotas
  SET
    daily_gen_count = 0,
    daily_gen_reset_date = CURRENT_DATE,
    updated_at = NOW()
  WHERE user_id = p_user_id
    AND (daily_gen_reset_date IS NULL OR daily_gen_reset_date < CURRENT_DATE);

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

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_user_quota_with_reset(UUID) TO authenticated;

-- Comment
COMMENT ON FUNCTION public.get_user_quota_with_reset(UUID) IS 'Get user quota with automatic daily reset. Use this function instead of direct SELECT to ensure daily_gen_count resets on new day.';
