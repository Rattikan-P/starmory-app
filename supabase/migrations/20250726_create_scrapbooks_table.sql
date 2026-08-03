-- Create scrapbooks table
CREATE TABLE IF NOT EXISTS public.scrapbooks (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    date TIMESTAMP WITH TIME ZONE NOT NULL,
    image_path TEXT NOT NULL,
    vocabulary_words JSONB DEFAULT '[]'::jsonb,
    english_sentence TEXT DEFAULT '',
    thai_sentence TEXT DEFAULT '',
    selected_emoji TEXT DEFAULT '😊',
    background_color BIGINT DEFAULT 4294967295, -- Unsigned ARGB, e.g. 0xFFFFFFFF
    text_overlays JSONB DEFAULT '[]'::jsonb,
    stickers JSONB DEFAULT '[]'::jsonb,
    additional_photos JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for faster queries by user_id
CREATE INDEX IF NOT EXISTS scrapbooks_user_id_idx ON public.scrapbooks(user_id);

-- Create index for date queries
CREATE INDEX IF NOT EXISTS scrapbooks_date_idx ON public.scrapbooks(date);

-- Create index for user+date queries (for calendar view)
CREATE INDEX IF NOT EXISTS scrapbooks_user_date_idx ON public.scrapbooks(user_id, date);

-- Enable Row Level Security
ALTER TABLE public.scrapbooks ENABLE ROW LEVEL SECURITY;

-- Create policy: Users can only see their own scrapbooks
CREATE POLICY "Users can view own scrapbooks"
    ON public.scrapbooks FOR SELECT
    USING (auth.uid() = user_id);

-- Create policy: Users can insert their own scrapbooks
CREATE POLICY "Users can insert own scrapbooks"
    ON public.scrapbooks FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Create policy: Users can update their own scrapbooks
CREATE POLICY "Users can update own scrapbooks"
    ON public.scrapbooks FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Create policy: Users can delete their own scrapbooks
CREATE POLICY "Users can delete own scrapbooks"
    ON public.scrapbooks FOR DELETE
    USING (auth.uid() = user_id);

-- Grant access to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON public.scrapbooks TO authenticated;

-- Optional: Add a function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to auto-update updated_at
CREATE TRIGGER update_scrapbooks_updated_at
    BEFORE UPDATE ON public.scrapbooks
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
