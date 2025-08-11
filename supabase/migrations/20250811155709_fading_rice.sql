/*
  # Fix user profiles schema and triggers

  1. Tables
    - Ensure `user_profiles` table has correct schema
    - Add proper foreign key relationship to auth.users
    
  2. Functions
    - Create trigger function to handle new user creation
    - Ensure first user gets manager role
    
  3. Security
    - Enable RLS on user_profiles table
    - Add policies for user access
    
  4. Triggers
    - Add trigger to automatically create profile on user signup
*/

-- Drop existing objects if they exist to recreate them properly
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP TRIGGER IF EXISTS assign_manager_trigger ON public.user_profiles;
DROP FUNCTION IF EXISTS public.assign_manager_to_first_user();

-- Create or recreate the user_profiles table with correct schema
CREATE TABLE IF NOT EXISTS public.user_profiles (
  id uuid REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email text UNIQUE NOT NULL,
  full_name text,
  roles text[] DEFAULT ARRAY['user'::text],
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- Create function to handle new user creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
  user_count integer;
BEGIN
  -- Count existing users
  SELECT COUNT(*) INTO user_count FROM public.user_profiles;
  
  -- Insert new user profile
  INSERT INTO public.user_profiles (id, email, full_name, roles)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    CASE 
      WHEN user_count = 0 THEN ARRAY['manager'::text]
      ELSE ARRAY['user'::text]
    END
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger on auth.users
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Create function to update updated_at column
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for updated_at
CREATE TRIGGER update_user_profiles_updated_at
  BEFORE UPDATE ON public.user_profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Create helper function to check if user is manager
CREATE OR REPLACE FUNCTION public.is_manager(user_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE id = user_id AND 'manager' = ANY(roles)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RLS Policies
CREATE POLICY "Users can view their own profile"
  ON public.user_profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
  ON public.user_profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Managers can view all profiles"
  ON public.user_profiles
  FOR SELECT
  TO authenticated
  USING (public.is_manager(auth.uid()));

CREATE POLICY "Managers can update all profiles"
  ON public.user_profiles
  FOR UPDATE
  TO authenticated
  USING (public.is_manager(auth.uid()));

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_email ON public.user_profiles(email);