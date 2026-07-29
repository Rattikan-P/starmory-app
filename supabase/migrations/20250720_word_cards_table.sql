-- Create word_cards table for FSRS (Free Spaced Repetition Scheduler) state management
-- Supports spaced repetition review system with adaptive memory algorithm

-- Ensure the update_updated_at_column function exists (created in initial schema)
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS public.word_cards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  vocabulary_id TEXT NOT NULL REFERENCES public.vocabularies(id) ON DELETE CASCADE,
  stability FLOAT DEFAULT 0,
  difficulty FLOAT DEFAULT 0,
  state TEXT DEFAULT 'new' CHECK (state IN ('new', 'learning', 'review', 'relearning')),
  due_date TIMESTAMPTZ DEFAULT NOW(),
  last_review TIMESTAMPTZ,
  reps INT DEFAULT 0,
  lapses INT DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, vocabulary_id)
);

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_word_cards_user_due ON public.word_cards(user_id, due_date);
CREATE INDEX IF NOT EXISTS idx_word_cards_vocabulary_id ON public.word_cards(vocabulary_id);

-- Enable RLS
ALTER TABLE public.word_cards ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view own word_cards
CREATE POLICY "Users can view own word_cards"
  ON public.word_cards FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Users can insert own word_cards
CREATE POLICY "Users can insert own word_cards"
  ON public.word_cards FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update own word_cards
CREATE POLICY "Users can update own word_cards"
  ON public.word_cards FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete own word_cards
CREATE POLICY "Users can delete own word_cards"
  ON public.word_cards FOR DELETE
  USING (auth.uid() = user_id);

-- Trigger to auto-update updated_at
DROP TRIGGER IF EXISTS update_word_cards_updated_at ON public.word_cards;
CREATE TRIGGER update_word_cards_updated_at
  BEFORE UPDATE ON public.word_cards
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Function to get due cards for a user (ordered by due_date)
CREATE OR REPLACE FUNCTION public.get_due_cards(
  p_user_id UUID,
  p_limit INT DEFAULT 5
)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  vocabulary_id TEXT,
  stability FLOAT,
  difficulty FLOAT,
  state TEXT,
  due_date TIMESTAMPTZ,
  last_review TIMESTAMPTZ,
  reps INT,
  lapses INT,
  word TEXT,
  meaning TEXT,
  example_sentence TEXT,
  photo_url TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    wc.id,
    wc.user_id,
    wc.vocabulary_id,
    wc.stability,
    wc.difficulty,
    wc.state,
    wc.due_date,
    wc.last_review,
    wc.reps,
    wc.lapses,
    v.word,
    v.thai_translation as meaning,
    v.english_sentence as example_sentence,
    v.image_url as photo_url
  FROM public.word_cards wc
  INNER JOIN public.vocabularies v ON wc.vocabulary_id = v.id
  WHERE wc.user_id = get_due_cards.p_user_id
    AND wc.due_date <= NOW()
  ORDER BY wc.due_date ASC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
