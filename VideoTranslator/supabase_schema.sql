-- VideoTranslator Supabase Schema
-- Run this in your Supabase SQL Editor

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table (extends auth.users)
CREATE TABLE IF NOT EXISTS public.users (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    is_anonymous BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Translation events table
CREATE TABLE IF NOT EXISTS public.translation_events (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    source_language TEXT NOT NULL,
    target_language TEXT NOT NULL,
    original_text TEXT NOT NULL,
    translated_text TEXT NOT NULL,
    duration_ms INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Session events table
CREATE TABLE IF NOT EXISTS public.session_events (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL CHECK (event_type IN ('session_start', 'session_end', 'translation', 'language_change')),
    video_duration_seconds DECIMAL(10,2) NOT NULL DEFAULT 0,
    language TEXT NOT NULL DEFAULT 'en',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User preferences table
CREATE TABLE IF NOT EXISTS public.user_preferences (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE UNIQUE,
    preferred_source_language TEXT DEFAULT 'en',
    preferred_target_language TEXT DEFAULT 'es',
    subtitle_style JSONB DEFAULT '{"fontSize": 16, "color": "#FFFFFF", "backgroundColor": "#00000080"}',
    auto_translate BOOLEAN DEFAULT false,
    api_key_encrypted TEXT, -- Encrypted API keys for translation services
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Admin roles table
CREATE TABLE IF NOT EXISTS public.admin_roles (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE UNIQUE,
    role TEXT NOT NULL CHECK (role IN ('admin', 'moderator', 'viewer')),
    granted_by UUID REFERENCES public.users(id),
    granted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_translation_events_user_id ON public.translation_events(user_id);
CREATE INDEX IF NOT EXISTS idx_translation_events_created_at ON public.translation_events(created_at);
CREATE INDEX IF NOT EXISTS idx_translation_events_target_language ON public.translation_events(target_language);

CREATE INDEX IF NOT EXISTS idx_session_events_user_id ON public.session_events(user_id);
CREATE INDEX IF NOT EXISTS idx_session_events_created_at ON public.session_events(created_at);
CREATE INDEX IF NOT EXISTS idx_session_events_event_type ON public.session_events(event_type);

CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON public.users(created_at);

-- Row Level Security (RLS) policies

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.translation_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.session_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_roles ENABLE ROW LEVEL SECURITY;

-- Users table policies
CREATE POLICY "Users can view own profile" ON public.users
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.users
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Admins can view all users" ON public.users
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.admin_roles 
            WHERE user_id = auth.uid() 
            AND is_active = true
            AND role IN ('admin', 'moderator', 'viewer')
        )
    );

-- Translation events policies
CREATE POLICY "Users can view own translation events" ON public.translation_events
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own translation events" ON public.translation_events
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can view all translation events" ON public.translation_events
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.admin_roles 
            WHERE user_id = auth.uid() 
            AND is_active = true
            AND role IN ('admin', 'moderator')
        )
    );

-- Session events policies
CREATE POLICY "Users can view own session events" ON public.session_events
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own session events" ON public.session_events
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can view all session events" ON public.session_events
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.admin_roles 
            WHERE user_id = auth.uid() 
            AND is_active = true
            AND role IN ('admin', 'moderator')
        )
    );

-- User preferences policies
CREATE POLICY "Users can view own preferences" ON public.user_preferences
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own preferences" ON public.user_preferences
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own preferences" ON public.user_preferences
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Admin roles policies
CREATE POLICY "Admins can view admin roles" ON public.admin_roles
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.admin_roles 
            WHERE user_id = auth.uid() 
            AND is_active = true
            AND role IN ('admin', 'moderator')
        )
    );

-- Functions for automatic user creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.users (id, email, display_name, is_anonymous)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
        false
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create user profile on signup
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_user_preferences_updated_at BEFORE UPDATE ON public.user_preferences
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Insert first admin (you need to replace with your actual user ID after first signup)
-- Uncomment and run this after you create your first account:
-- INSERT INTO public.admin_roles (user_id, role, granted_by)
-- VALUES ('YOUR_USER_ID_HERE', 'admin', 'YOUR_USER_ID_HERE');

-- Views for common analytics queries
CREATE OR REPLACE VIEW public.user_translation_stats AS
SELECT 
    u.id,
    u.email,
    u.display_name,
    COUNT(te.id) as total_translations,
    COUNT(DISTINCT te.target_language) as unique_languages,
    MAX(te.created_at) as last_translation,
    AVG(te.duration_ms) as avg_translation_duration
FROM public.users u
LEFT JOIN public.translation_events te ON u.id = te.user_id
GROUP BY u.id, u.email, u.display_name;

CREATE OR REPLACE VIEW public.daily_translation_stats AS
SELECT 
    DATE(te.created_at) as date,
    COUNT(*) as total_translations,
    COUNT(DISTINCT te.user_id) as unique_users,
    COUNT(DISTINCT te.target_language) as unique_languages,
    te.target_language,
    AVG(te.duration_ms) as avg_duration_ms
FROM public.translation_events te
GROUP BY DATE(te.created_at), te.target_language
ORDER BY date DESC, total_translations DESC;

CREATE OR REPLACE VIEW public.language_popularity AS
SELECT 
    target_language,
    COUNT(*) as usage_count,
    COUNT(DISTINCT user_id) as unique_users,
    AVG(duration_ms) as avg_duration_ms,
    MAX(created_at) as last_used
FROM public.translation_events
GROUP BY target_language
ORDER BY usage_count DESC;
