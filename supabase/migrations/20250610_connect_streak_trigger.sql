-- Connect streak update trigger to vocabularies table
-- This automatically updates user streak when they save new vocabulary
-- Migration: 20250610_connect_streak_trigger.sql

-- First, drop the trigger if it exists (created by previous manual run or migration)
DROP TRIGGER IF EXISTS on_vocabulary_inserted ON public.vocabularies;

-- Now drop and recreate the function
DROP FUNCTION IF EXISTS public.update_streak_after_activity() CASCADE;

CREATE OR REPLACE FUNCTION public.update_streak_after_activity()
RETURNS TRIGGER AS $$
DECLARE
  last_date DATE;
  current_streak_val INTEGER;
  shields_val INTEGER;
  longest_val INTEGER;
BEGIN
  -- Get current streak data for the user
  SELECT
    current_streak,
    shields_available,
    longest_streak,
    last_activity_date
  INTO
    current_streak_val,
    shields_val,
    longest_val,
    last_date
  FROM public.users
  WHERE id = NEW.user_id;

  -- If first activity ever (no last_activity_date)
  IF last_date IS NULL THEN
    UPDATE public.users
    SET
      current_streak = 1,
      longest_streak = GREATEST(longest_streak, 1),
      last_activity_date = CURRENT_DATE
    WHERE id = NEW.user_id;

  -- If activity on same day - update date only (don't increment streak again)
  ELSIF last_date = CURRENT_DATE THEN
    -- Already incremented today, just update the timestamp
    UPDATE public.users
    SET last_activity_date = CURRENT_DATE
    WHERE id = NEW.user_id;

  -- If activity within grace period (within 48 hours = 2 days)
  -- This handles edge case: activity at 23:59 yesterday and 00:01 today
  ELSIF AGE(CURRENT_DATE, last_date) <= INTERVAL '48 hours' THEN
    current_streak_val := current_streak_val + 1;

    -- Earn shield every 7 consecutive days
    IF current_streak_val % 7 = 0 THEN
      shields_val := shields_val + 1;
    END IF;

    -- Update streak and longest streak
    UPDATE public.users
    SET
      current_streak = current_streak_val,
      longest_streak = GREATEST(longest_val, current_streak_val),
      shields_available = shields_val,
      last_activity_date = CURRENT_DATE
    WHERE id = NEW.user_id;

  -- If missed more than grace period (gap of 3+ days) - use shield if available
  ELSE
    -- Check if we have shields to protect the streak
    IF shields_val > 0 THEN
      -- Use one shield (protect streak - keeps same value)
      shields_val := shields_val - 1;

      UPDATE public.users
      SET
        shields_available = shields_val,
        last_activity_date = CURRENT_DATE
      WHERE id = NEW.user_id;
    ELSE
      -- No shields available - reset streak to 1
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

-- Create trigger on vocabularies table
-- This fires every time a user saves a new vocabulary
CREATE TRIGGER on_vocabulary_inserted
  AFTER INSERT ON public.vocabularies
  FOR EACH ROW
  EXECUTE FUNCTION public.update_streak_after_activity();

-- Add comment for documentation
COMMENT ON TRIGGER on_vocabulary_inserted ON public.vocabularies IS
  'Automatically updates user streak when new vocabulary is saved.
   Handles consecutive days, shield earning, and streak protection.';
