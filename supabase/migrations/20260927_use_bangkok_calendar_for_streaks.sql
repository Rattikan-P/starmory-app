-- Use one calendar date for streak activity on both the app and database.
-- Supabase stores dates in UTC by default, while Starmory's streak UI follows
-- the Bangkok calendar. This avoids treating one Bangkok day as two days.
CREATE OR REPLACE FUNCTION public.update_streak_after_activity()
RETURNS TRIGGER AS $$
DECLARE
  last_date DATE;
  current_streak_val INTEGER;
  shields_val INTEGER;
  longest_val INTEGER;
  today_date DATE := (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Bangkok')::DATE;
  days_since_last INTEGER;
BEGIN
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

  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  IF last_date IS NULL THEN
    UPDATE public.users
    SET
      current_streak = 1,
      longest_streak = GREATEST(longest_val, 1),
      last_activity_date = today_date
    WHERE id = NEW.user_id;
    RETURN NEW;
  END IF;

  -- Clamp legacy future dates without awarding an extra streak day.
  IF last_date > today_date THEN
    UPDATE public.users
    SET last_activity_date = today_date
    WHERE id = NEW.user_id;
    RETURN NEW;
  END IF;

  IF last_date = today_date THEN
    UPDATE public.users
    SET last_activity_date = today_date
    WHERE id = NEW.user_id;
    RETURN NEW;
  END IF;

  days_since_last := today_date - last_date;

  -- Keep the existing 48-hour grace period, now measured in Bangkok dates.
  IF days_since_last <= 2 THEN
    current_streak_val := current_streak_val + 1;

    IF current_streak_val % 7 = 0 THEN
      shields_val := shields_val + 1;
    END IF;

    UPDATE public.users
    SET
      current_streak = current_streak_val,
      longest_streak = GREATEST(longest_val, current_streak_val),
      shields_available = shields_val,
      last_activity_date = today_date
    WHERE id = NEW.user_id;
  ELSIF shields_val > 0 THEN
    UPDATE public.users
    SET
      shields_available = shields_val - 1,
      last_activity_date = today_date
    WHERE id = NEW.user_id;
  ELSE
    UPDATE public.users
    SET
      current_streak = 1,
      longest_streak = GREATEST(longest_val, 1),
      last_activity_date = today_date
    WHERE id = NEW.user_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
