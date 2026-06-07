-- Add streak-related columns to users table
-- This tracks user learning streaks and shield system

-- Add streak columns to users table
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS current_streak INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS shields_available INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS longest_streak INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_activity_date DATE;

-- Add index for streak queries (useful for leaderboards, streak-based features)
CREATE INDEX IF NOT EXISTS idx_users_current_streak ON public.users(current_streak);
CREATE INDEX IF NOT EXISTS idx_users_last_activity ON public.users(last_activity_date);

-- Comment on columns for documentation
COMMENT ON COLUMN public.users.current_streak IS 'Current consecutive days of learning';
COMMENT ON COLUMN public.users.shields_available IS 'Number of shields that protect streak when missing a day';
COMMENT ON COLUMN public.users.longest_streak IS 'Longest streak ever achieved by user';
COMMENT ON COLUMN public.users.last_activity_date IS 'Last date user was active (used for streak calculation)';

-- Function: Update streak after user activity
CREATE OR REPLACE FUNCTION public.update_streak_after_activity()
RETURNS TRIGGER AS $$
DECLARE
  last_date DATE;
  current_streak_val INTEGER;
  shields_val INTEGER;
BEGIN
  -- Get current streak data
  SELECT
    current_streak,
    shields_available,
    last_activity_date
  INTO
    current_streak_val,
    shields_val,
    last_date
  FROM public.users
  WHERE id = NEW.user_id;

  -- If first activity ever
  IF last_date IS NULL THEN
    UPDATE public.users
    SET
      current_streak = 1,
      last_activity_date = CURRENT_DATE
    WHERE id = NEW.user_id;

  -- If activity on same day - do nothing
  ELSIF last_date = CURRENT_DATE THEN
    NULL; -- Already updated today

  -- If activity on consecutive day (yesterday)
  ELSIF last_date = CURRENT_DATE - INTERVAL '1 day' THEN
    current_streak_val := current_streak_val + 1;

    -- Earn shield every 7 consecutive days
    IF current_streak_val % 7 = 0 THEN
      shields_val := shields_val + 1;
    END IF;

    -- Update longest streak if needed
    UPDATE public.users
    SET
      current_streak = current_streak_val,
      longest_streak = GREATEST(longest_streak, current_streak_val),
      shields_available = shields_val,
      last_activity_date = CURRENT_DATE
    WHERE id = NEW.user_id;

  -- If missed a day (gap of 2+ days) - use shield if available
  ELSIF last_date < CURRENT_DATE - INTERVAL '1 day' THEN
    -- Calculate days missed
    IF (CURRENT_DATE - last_date) > INTERVAL '1 day' AND shields_val > 0 THEN
      -- Use one shield
      shields_val := shields_val - 1;

      UPDATE public.users
      SET
        shields_available = shields_val,
        last_activity_date = CURRENT_DATE
      WHERE id = NEW.user_id;
    ELSE
      -- No shields available - reset streak
      UPDATE public.users
      SET
        current_streak = 1,
        last_activity_date = CURRENT_DATE
      WHERE id = NEW.user_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Note: This trigger should be attached to the activity/learning table
-- when it's created. For now, the function is ready to use.
--
-- Example usage when activity table exists:
-- CREATE TRIGGER on_activity_completed
--   AFTER INSERT ON user_learning_activities
--   FOR EACH ROW
--   EXECUTE FUNCTION public.update_streak_after_activity();

-- Helper function: Get user streak status
CREATE OR REPLACE FUNCTION public.get_user_streak_status(user_uuid UUID)
RETURNS TABLE (
  current_streak INTEGER,
  longest_streak INTEGER,
  shields_available INTEGER,
  last_activity_date DATE,
  days_since_last_activity INTEGER,
  consecutive_days INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    u.current_streak::INTEGER,
    u.longest_streak::INTEGER,
    u.shields_available::INTEGER,
    u.last_activity_date,
    (CURRENT_DATE - u.last_activity_date)::INTEGER as days_since_last_activity,
    (u.current_streak % 7)::INTEGER as consecutive_days
  FROM public.users u
  WHERE u.id = get_user_streak_status.user_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function: Manual streak update (for testing or admin use)
CREATE OR REPLACE FUNCTION public.manual_update_streak(
  user_uuid UUID,
  new_streak INTEGER DEFAULT NULL,
  add_shields INTEGER DEFAULT 0
)
RETURNS JSONB AS $$
DECLARE
  result JSONB;
BEGIN
  IF new_streak IS NOT NULL THEN
    UPDATE public.users
    SET current_streak = new_streak,
        longest_streak = GREATEST(longest_streak, new_streak)
    WHERE id = user_uuid;
  END IF;

  IF add_shields != 0 THEN
    UPDATE public.users
    SET shields_available = GREATEST(0, shields_available + add_shields)
    WHERE id = user_uuid;
  END IF;

  -- Return updated status
  SELECT jsonb_build_object(
    'user_id', user_uuid,
    'current_streak', current_streak,
    'longest_streak', longest_streak,
    'shields_available', shields_available
  ) INTO result
  FROM public.users
    WHERE id = user_uuid;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
