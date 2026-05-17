-- Create user_quotas table for tracking AI generation quotas
CREATE TABLE IF NOT EXISTS public.user_quotas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  daily_gen_count INTEGER NOT NULL DEFAULT 0,
  daily_gen_reset_date DATE NOT NULL DEFAULT CURRENT_DATE,
  total_gen_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT user_quotas_user_id_key UNIQUE(user_id)
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_quotas_user_id ON public.user_quotas(user_id);

-- Enable RLS
ALTER TABLE public.user_quotas ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read their own quota
CREATE POLICY "Users can view own quota"
  ON public.user_quotas FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Users can insert their own quota (handled by trigger)
CREATE POLICY "Users can insert own quota"
  ON public.user_quotas FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own quota
CREATE POLICY "Users can update own quota"
  ON public.user_quotas FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Function to create quota record on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user_quotas()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_quotas (user_id)
  VALUES (NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create quota on signup
DROP TRIGGER IF EXISTS on_auth_user_created_quotas ON auth.users;
CREATE TRIGGER on_auth_user_created_quotas
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user_quotas();

-- Function to auto-reset daily quota
CREATE OR REPLACE FUNCTION public.reset_daily_quota_if_needed()
RETURNS TABLE (
  user_id UUID,
  reset_count INTEGER
) AS $$
DECLARE
  reset_records RECORD;
BEGIN
  -- Update records where reset_date is not today
  FOR reset_records IN
    UPDATE public.user_quotas
    SET
      daily_gen_count = 0,
      daily_gen_reset_date = CURRENT_DATE,
      updated_at = NOW()
    WHERE daily_gen_reset_date < CURRENT_DATE
    RETURNING user_id, daily_gen_count
  LOOP
    RETURN QUERY SELECT reset_records.user_id, reset_records.daily_gen_count;
  END LOOP;
  RETURN;
END;
$$ LANGUAGE plpgsql;

-- Helper function to get current quota status
CREATE OR REPLACE FUNCTION public.get_user_quota_status(user_uuid UUID)
RETURNS TABLE (
  daily_remaining INTEGER,
  total_used INTEGER,
  is_reset_today BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    GREATEST(0, 15 - uq.daily_gen_count)::INTEGER as daily_remaining,
    uq.total_gen_count::INTEGER as total_used,
    (uq.daily_gen_reset_date = CURRENT_DATE)::BOOLEAN as is_reset_today
  FROM public.user_quotas uq
  WHERE uq.user_id = get_user_quota_status.user_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
