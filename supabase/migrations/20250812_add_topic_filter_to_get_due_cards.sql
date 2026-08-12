-- Add topic filter parameter to get_due_cards function
-- This allows filtering due cards by category

-- Drop old function
DROP FUNCTION IF EXISTS public.get_due_cards(UUID, INT);

-- Recreate function with topic filter support
CREATE OR REPLACE FUNCTION public.get_due_cards(
  p_user_id UUID,
  p_limit INT DEFAULT 5,
  p_topic_filter TEXT DEFAULT NULL
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
  photo_url TEXT,
  topic TEXT
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
    v.image_url as photo_url,
    v.topic
  FROM public.word_cards wc
  INNER JOIN public.vocabularies v ON wc.vocabulary_id = v.id
  WHERE wc.user_id = get_due_cards.p_user_id
    AND wc.due_date <= NOW()
    AND (p_topic_filter IS NULL OR v.topic = p_topic_filter)
  ORDER BY wc.due_date ASC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.get_due_cards(UUID, INT, TEXT) TO authenticated;
