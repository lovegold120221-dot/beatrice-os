-- Memories table for Beatrice long-term memory
CREATE TABLE IF NOT EXISTS public.memories (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN (
    'user_preference',
    'fact',
    'context',
    'instruction',
    'emotion',
    'relationship'
  )),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_accessed TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id, content)
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_memories_user_id ON public.memories(user_id);
CREATE INDEX IF NOT EXISTS idx_memories_last_accessed ON public.memories(last_accessed DESC);
CREATE INDEX IF NOT EXISTS idx_memories_category ON public.memories(category);

-- Row Level Security
ALTER TABLE public.memories ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only access their own memories
CREATE POLICY "Users can view their own memories"
  ON public.memories FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own memories"
  ON public.memories FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own memories"
  ON public.memories FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own memories"
  ON public.memories FOR DELETE
  USING (auth.uid() = user_id);

-- Function to touch memory (update last_accessed)
CREATE OR REPLACE FUNCTION touch_memory(memory_id UUID)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.memories
  SET last_accessed = NOW()
  WHERE id = memory_id;
END;
$$;

-- Optional: Cleanup old unused memories (run periodically via pg_cron or pgAgent)
-- DELETE FROM public.memories
-- WHERE last_accessed < NOW() - INTERVAL '6 months'
-- AND category NOT IN ('user_preference', 'fact');

-- Chats table for conversation sessions
CREATE TABLE IF NOT EXISTS public.chats (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL DEFAULT '',
  context_text TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Messages table for individual chat messages
CREATE TABLE IF NOT EXISTS public.messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  chat_id UUID NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL,
  text TEXT NOT NULL DEFAULT '',
  image_url TEXT DEFAULT '',
  is_image_gen BOOLEAN DEFAULT FALSE,
  original_prompt TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_messages_chat_id ON public.messages(chat_id);
CREATE INDEX IF NOT EXISTS idx_chats_user_id ON public.chats(user_id);

ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own chats"
  ON public.chats FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own chats"
  ON public.chats FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own chats"
  ON public.chats FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own chats"
  ON public.chats FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users can view their own messages"
  ON public.messages FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.chats WHERE id = chat_id AND user_id = auth.uid())
  );
CREATE POLICY "Users can insert messages to their chats"
  ON public.messages FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.chats WHERE id = chat_id AND user_id = auth.uid())
  );
CREATE POLICY "Users can delete their own messages"
  ON public.messages FOR DELETE USING (
    EXISTS (SELECT 1 FROM public.chats WHERE id = chat_id AND user_id = auth.uid())
  );

-- Device profiles table for unauthenticated user preferences
CREATE TABLE IF NOT EXISTS public.device_profiles (
  device_id TEXT PRIMARY KEY,
  user_context TEXT DEFAULT '',
  response_style TEXT DEFAULT '',
  theme TEXT DEFAULT 'system',
  ollama_model TEXT DEFAULT '',
  last_seen_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Row Level Security
ALTER TABLE public.device_profiles ENABLE ROW LEVEL SECURITY;

-- Allow public read/insert/update by device_id (no auth required)
CREATE POLICY "Anyone can read device_profiles"
  ON public.device_profiles FOR SELECT
  USING (true);

CREATE POLICY "Anyone can insert device_profiles"
  ON public.device_profiles FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Anyone can update device_profiles"
  ON public.device_profiles FOR UPDATE
  USING (true);