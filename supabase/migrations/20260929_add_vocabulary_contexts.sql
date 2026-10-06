-- Keep one vocabulary and FSRS card per unique word while preserving the
-- photo/example contexts that were previously saved as duplicate vocabularies.
ALTER TABLE public.vocabularies
  ADD COLUMN IF NOT EXISTS additional_examples JSONB NOT NULL DEFAULT '[]'::JSONB;

WITH ranked_vocabularies AS (
  SELECT
    v.id,
    v.user_id,
    LOWER(BTRIM(v.word)) AS word_key,
    ROW_NUMBER() OVER (
      PARTITION BY v.user_id, LOWER(BTRIM(v.word))
      ORDER BY COALESCE(wc.reps, 0) DESC,
               wc.last_review DESC NULLS LAST,
               v.created_at ASC,
               v.id ASC
    ) AS row_number
  FROM public.vocabularies AS v
  LEFT JOIN public.word_cards AS wc
    ON wc.user_id = v.user_id AND wc.vocabulary_id = v.id
), canonical_vocabularies AS (
  SELECT id, user_id, word_key
  FROM ranked_vocabularies
  WHERE row_number = 1
), duplicate_contexts AS (
  SELECT
    canonical.id AS canonical_id,
    canonical.user_id,
    duplicate.id AS duplicate_id,
    jsonb_build_object(
      'imageUrl', duplicate.image_url,
      'englishSentence', duplicate.english_sentence,
      'thaiSentence', duplicate.thai_sentence,
      'createdAt', duplicate.created_at
    ) AS primary_example
  FROM canonical_vocabularies AS canonical
  JOIN public.vocabularies AS duplicate
    ON duplicate.user_id = canonical.user_id
   AND LOWER(BTRIM(duplicate.word)) = canonical.word_key
   AND duplicate.id <> canonical.id
), extra_contexts AS (
  SELECT canonical_id, user_id, primary_example AS example
  FROM duplicate_contexts
  UNION ALL
  SELECT dc.canonical_id, dc.user_id, alternate.example
  FROM duplicate_contexts AS dc
  JOIN public.vocabularies AS duplicate ON duplicate.id = dc.duplicate_id
  CROSS JOIN LATERAL jsonb_array_elements(
    COALESCE(duplicate.additional_examples, '[]'::JSONB)
  ) AS alternate(example)
), merged_contexts AS (
  SELECT canonical_id, user_id, jsonb_agg(DISTINCT example) AS examples
  FROM extra_contexts
  GROUP BY canonical_id, user_id
)
UPDATE public.vocabularies AS canonical
SET additional_examples = COALESCE(canonical.additional_examples, '[]'::JSONB)
  || merged_contexts.examples
FROM merged_contexts
WHERE canonical.id = merged_contexts.canonical_id
  AND canonical.user_id = merged_contexts.user_id;

-- Keep the most practiced card for each word; deleting duplicate vocabulary
-- rows cascades their duplicate word_cards.
WITH ranked_vocabularies AS (
  SELECT
    v.id,
    ROW_NUMBER() OVER (
      PARTITION BY v.user_id, LOWER(BTRIM(v.word))
      ORDER BY COALESCE(wc.reps, 0) DESC,
               wc.last_review DESC NULLS LAST,
               v.created_at ASC,
               v.id ASC
    ) AS row_number
  FROM public.vocabularies AS v
  LEFT JOIN public.word_cards AS wc
    ON wc.user_id = v.user_id AND wc.vocabulary_id = v.id
)
DELETE FROM public.vocabularies AS duplicate
USING ranked_vocabularies AS ranked
WHERE duplicate.id = ranked.id
  AND ranked.row_number > 1;
