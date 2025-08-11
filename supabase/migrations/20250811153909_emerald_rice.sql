/*
  # Initial Schema Setup for Transaction Management System

  1. New Tables
    - `user_profiles` - Extended user information and roles
      - `id` (uuid, primary key, references auth.users)
      - `email` (text, unique)
      - `full_name` (text)
      - `roles` (text array, defaults to ['user'])
      - `created_at` (timestamp)
      - `updated_at` (timestamp)
    
    - `transactions` - Financial transaction records
      - `id` (uuid, primary key)
      - `sender_id` (uuid, references user_profiles)
      - `receiver_id` (uuid, references user_profiles)
      - `reason` (text)
      - `amount` (decimal)
      - `status` (text, enum: pending, completed, cancelled)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Security
    - Enable RLS on all tables
    - Create policies for role-based access control
    - Manager role can access all data
    - User role can only access their own transactions

  3. Functions
    - Function to automatically assign manager role to first user
    - Trigger to create user profile on auth signup
*/

-- Create user_profiles table
CREATE TABLE IF NOT EXISTS user_profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text UNIQUE NOT NULL,
  full_name text,
  roles text[] DEFAULT ARRAY['user'],
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create transactions table
CREATE TABLE IF NOT EXISTS transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id uuid REFERENCES user_profiles(id) ON DELETE CASCADE,
  receiver_id uuid REFERENCES user_profiles(id) ON DELETE CASCADE,
  reason text NOT NULL,
  amount decimal(12,2) NOT NULL,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'cancelled')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_transactions_sender_id ON transactions(sender_id);
CREATE INDEX IF NOT EXISTS idx_transactions_receiver_id ON transactions(receiver_id);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at);
CREATE INDEX IF NOT EXISTS idx_user_profiles_email ON user_profiles(email);

-- Function to check if user is manager
CREATE OR REPLACE FUNCTION is_manager(user_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE id = user_id AND 'manager' = ANY(roles)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to assign manager role to first user
CREATE OR REPLACE FUNCTION assign_manager_to_first_user()
RETURNS trigger AS $$
BEGIN
  -- Check if this is the first user
  IF (SELECT COUNT(*) FROM user_profiles) = 0 THEN
    NEW.roles = ARRAY['manager'];
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to handle new user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO user_profiles (id, email, full_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Triggers
CREATE OR REPLACE TRIGGER assign_manager_trigger
  BEFORE INSERT ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION assign_manager_to_first_user();

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- Update trigger for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER update_user_profiles_updated_at
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER update_transactions_updated_at
  BEFORE UPDATE ON transactions
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- RLS Policies for user_profiles
CREATE POLICY "Users can view their own profile" ON user_profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Managers can view all profiles" ON user_profiles
  FOR SELECT USING (is_manager(auth.uid()));

CREATE POLICY "Users can update their own profile" ON user_profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Managers can update all profiles" ON user_profiles
  FOR UPDATE USING (is_manager(auth.uid()));

-- RLS Policies for transactions
CREATE POLICY "Users can view their own transactions" ON transactions
  FOR SELECT USING (
    auth.uid() = sender_id OR 
    auth.uid() = receiver_id OR 
    is_manager(auth.uid())
  );

CREATE POLICY "Managers can insert transactions" ON transactions
  FOR INSERT WITH CHECK (is_manager(auth.uid()));

CREATE POLICY "Managers can update transactions" ON transactions
  FOR UPDATE USING (is_manager(auth.uid()));

CREATE POLICY "Managers can delete transactions" ON transactions
  FOR DELETE USING (is_manager(auth.uid()));

-- Insert sample data (only if tables are empty)
DO $$
BEGIN
  -- Sample users will be created through auth signup
  -- Sample transactions will be inserted after users exist
  NULL;
END $$;