-- Store one row per user and local calendar day with learning activity.
CREATE TABLE IF NOT EXISTS public.learning_activity_days (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  activity_date DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, activity_date)
);

ALTER TABLE public.learning_activity_days ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own learning activity days"
  ON public.learning_activity_days FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own learning activity days"
  ON public.learning_activity_days FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own learning activity days"
  ON public.learning_activity_days FOR DELETE
  USING (auth.uid() = user_id);
