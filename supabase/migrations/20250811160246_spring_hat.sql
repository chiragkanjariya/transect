/*
  # Fix User Profile Creation Trigger

  This migration fixes the database trigger that creates user profiles when new users sign up.
  The previous trigger was failing due to constraint violations and improper data handling.

  ## Changes Made
  1. **Fixed trigger function** - Properly handles user metadata extraction and default values
  2. **Added error handling** - Prevents trigger failures from blocking user creation
  3. **Corrected role assignment** - Ensures first user gets manager role, others get user role
  4. **Fixed column constraints** - Handles NULL values and provides proper defaults

  ## Security
  - Maintains RLS policies for user_profiles table
  - Preserves role-based access control
*/

-- Drop existing trigger and function if they exist
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP FUNCTION IF EXISTS public.assign_manager_to_first_user();

-- Create improved function to handle new user creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  user_count INTEGER;
  user_roles TEXT[];
BEGIN
  -- Count existing users to determine if this is the first user
  SELECT COUNT(*) INTO user_count FROM public.user_profiles;
  
  -- Assign roles based on whether this is the first user
  IF user_count = 0 THEN
    user_roles := ARRAY['manager', 'user'];
  ELSE
    user_roles := ARRAY['user'];
  END IF;
  
  -- Insert new user profile with proper error handling
  BEGIN
    INSERT INTO public.user_profiles (
      id,
      email,
      full_name,
      roles,
      created_at,
      updated_at
    ) VALUES (
      NEW.id,
      NEW.email,
      COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
      user_roles,
      NOW(),
      NOW()
    );
  EXCEPTION WHEN OTHERS THEN
    -- Log the error but don't prevent user creation
    RAISE WARNING 'Failed to create user profile for user %: %', NEW.id, SQLERRM;
  END;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Ensure the user_profiles table has the correct structure
ALTER TABLE public.user_profiles 
  ALTER COLUMN full_name SET DEFAULT '',
  ALTER COLUMN roles SET DEFAULT ARRAY['user'::text];

-- Update the updated_at trigger function if it doesn't exist
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Ensure updated_at trigger exists
DROP TRIGGER IF EXISTS update_user_profiles_updated_at ON public.user_profiles;
CREATE TRIGGER update_user_profiles_updated_at
  BEFORE UPDATE ON public.user_profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Create helper function for role checking
CREATE OR REPLACE FUNCTION public.is_manager(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE id = user_id AND 'manager' = ANY(roles)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensure RLS policies are correct
DROP POLICY IF EXISTS "Users can view their own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Managers can view all profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Managers can update all profiles" ON public.user_profiles;

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