/*
  # Create user profiles schema

  1. New Tables
    - `user_profiles`
      - `id` (uuid, primary key, references auth.users)
      - `full_name` (text)
      - `email` (text, unique)
      - `roles` (text array, default ['user'])
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Security
    - Enable RLS on `user_profiles` table
    - Add policies for public viewing, self-management, and manager privileges
    - Add trigger to automatically create profile on user signup

  3. Functions
    - `handle_new_user()` - Creates user profile when new user signs up
    - Automatic `updated_at` timestamp handling
*/

-- Create the user_profiles table
CREATE TABLE IF NOT EXISTS public.user_profiles (
  id uuid REFERENCES auth.users ON DELETE CASCADE NOT NULL PRIMARY KEY,
  full_name text,
  email text UNIQUE,
  roles text[] DEFAULT '{user}'::text[] NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Set up Row Level Security (RLS) for user_profiles
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Public profiles are viewable by everyone." ON public.user_profiles;
DROP POLICY IF EXISTS "Users can insert their own profile." ON public.user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile." ON public.user_profiles;
DROP POLICY IF EXISTS "Managers can view all profiles." ON public.user_profiles;
DROP POLICY IF EXISTS "Managers can update any profile." ON public.user_profiles;
DROP POLICY IF EXISTS "Managers can delete any profile." ON public.user_profiles;

-- Create RLS policies
CREATE POLICY "Public profiles are viewable by everyone." ON public.user_profiles FOR SELECT USING (true);
CREATE POLICY "Users can insert their own profile." ON public.user_profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can update their own profile." ON public.user_profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Managers can view all profiles." ON public.user_profiles FOR SELECT USING (EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND 'manager' = ANY(roles)));
CREATE POLICY "Managers can update any profile." ON public.user_profiles FOR UPDATE USING (EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND 'manager' = ANY(roles)));
CREATE POLICY "Managers can delete any profile." ON public.user_profiles FOR DELETE USING (EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND 'manager' = ANY(roles)));

-- Drop existing function and trigger if they exist
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- Create a function to create a user profile on new user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_profiles (id, email, full_name)
  VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'full_name');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a trigger to call the function on new user signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for automatic updated_at handling
DROP TRIGGER IF EXISTS handle_updated_at ON public.user_profiles;
CREATE TRIGGER handle_updated_at 
  BEFORE UPDATE ON public.user_profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();