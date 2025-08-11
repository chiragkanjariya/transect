/*
  # Complete Database Schema Setup

  1. New Tables
    - `user_profiles`
      - `id` (uuid, primary key, references auth.users)
      - `email` (text, unique)
      - `full_name` (text, nullable)
      - `roles` (text array, default ['user'])
      - `created_at` (timestamp)
      - `updated_at` (timestamp)
    
    - `user_balances`
      - `user_id` (uuid, primary key, references user_profiles)
      - `balance` (numeric, default 1000.00)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)
    
    - `transactions`
      - `id` (uuid, primary key)
      - `sender_id` (uuid, references user_profiles)
      - `receiver_id` (uuid, references user_profiles)
      - `reason` (text)
      - `amount` (numeric)
      - `status` (text, check constraint)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users
    - Add manager-specific policies
    - Add user-specific access policies

  3. Functions & Triggers
    - Auto-create user profile on signup
    - Auto-create user balance
    - Auto-update timestamps
    - Process transactions (update balances)
    - Assign manager role to first user

  4. Indexes
    - Performance indexes on frequently queried columns
*/

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create updated_at function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create user_profiles table
CREATE TABLE IF NOT EXISTS user_profiles (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email text UNIQUE NOT NULL,
    full_name text,
    roles text[] DEFAULT ARRAY['user'::text],
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Create user_balances table
CREATE TABLE IF NOT EXISTS user_balances (
    user_id uuid PRIMARY KEY REFERENCES user_profiles(id) ON DELETE CASCADE,
    balance numeric(12,2) DEFAULT 1000.00 NOT NULL,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Create transactions table
CREATE TABLE IF NOT EXISTS transactions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id uuid REFERENCES user_profiles(id) ON DELETE CASCADE,
    receiver_id uuid REFERENCES user_profiles(id) ON DELETE CASCADE,
    reason text NOT NULL,
    amount numeric(12,2) NOT NULL,
    status text DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'cancelled')),
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_email ON user_profiles(email);
CREATE INDEX IF NOT EXISTS idx_transactions_sender_id ON transactions(sender_id);
CREATE INDEX IF NOT EXISTS idx_transactions_receiver_id ON transactions(receiver_id);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at);

-- Enable RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

-- Helper function to check if user is manager
CREATE OR REPLACE FUNCTION is_manager(user_id uuid)
RETURNS boolean AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = user_id AND 'manager' = ANY(roles)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- User Profiles RLS Policies
CREATE POLICY "Public profiles are viewable by everyone" ON user_profiles
    FOR SELECT USING (true);

CREATE POLICY "Users can insert their own profile" ON user_profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON user_profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Managers can view all profiles" ON user_profiles
    FOR SELECT USING (is_manager(auth.uid()));

CREATE POLICY "Managers can update all profiles" ON user_profiles
    FOR UPDATE USING (is_manager(auth.uid()));

CREATE POLICY "Managers can delete any profile" ON user_profiles
    FOR DELETE USING (is_manager(auth.uid()));

-- User Balances RLS Policies
CREATE POLICY "Users can view their own balance" ON user_balances
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Managers can view all balances" ON user_balances
    FOR SELECT TO authenticated USING (is_manager(auth.uid()));

CREATE POLICY "System can insert balances" ON user_balances
    FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Managers can update balances" ON user_balances
    FOR UPDATE TO authenticated USING (is_manager(auth.uid()));

-- Transactions RLS Policies
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

-- Function to handle new user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger AS $$
DECLARE
    user_count integer;
    user_roles text[];
BEGIN
    -- Count existing users
    SELECT COUNT(*) INTO user_count FROM user_profiles;
    
    -- Set roles: first user gets manager + user, others get just user
    IF user_count = 0 THEN
        user_roles := ARRAY['manager', 'user'];
    ELSE
        user_roles := ARRAY['user'];
    END IF;
    
    -- Insert user profile
    INSERT INTO user_profiles (id, email, full_name, roles)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
        user_roles
    );
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- Log error but don't fail the user creation
        RAISE WARNING 'Error creating user profile: %', SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create user balance
CREATE OR REPLACE FUNCTION create_user_balance()
RETURNS trigger AS $$
BEGIN
    INSERT INTO user_balances (user_id, balance)
    VALUES (NEW.id, 1000.00);
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error creating user balance: %', SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to process transaction (update balances)
CREATE OR REPLACE FUNCTION process_transaction()
RETURNS trigger AS $$
BEGIN
    -- Only process when status changes to completed
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
        -- Update sender balance (subtract)
        UPDATE user_balances 
        SET balance = balance - NEW.amount
        WHERE user_id = NEW.sender_id;
        
        -- Update receiver balance (add)
        UPDATE user_balances 
        SET balance = balance + NEW.amount
        WHERE user_id = NEW.receiver_id;
        
    -- Reverse transaction if cancelled after being completed
    ELSIF NEW.status = 'cancelled' AND OLD.status = 'completed' THEN
        -- Reverse: add back to sender
        UPDATE user_balances 
        SET balance = balance + NEW.amount
        WHERE user_id = NEW.sender_id;
        
        -- Reverse: subtract from receiver
        UPDATE user_balances 
        SET balance = balance - NEW.amount
        WHERE user_id = NEW.receiver_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

DROP TRIGGER IF EXISTS create_user_balance_trigger ON user_profiles;
CREATE TRIGGER create_user_balance_trigger
    AFTER INSERT ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION create_user_balance();

DROP TRIGGER IF EXISTS process_transaction_trigger ON transactions;
CREATE TRIGGER process_transaction_trigger
    AFTER UPDATE ON transactions
    FOR EACH ROW EXECUTE FUNCTION process_transaction();

-- Update triggers for updated_at
DROP TRIGGER IF EXISTS update_user_profiles_updated_at ON user_profiles;
CREATE TRIGGER update_user_profiles_updated_at
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_user_balances_updated_at ON user_balances;
CREATE TRIGGER update_user_balances_updated_at
    BEFORE UPDATE ON user_balances
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_transactions_updated_at ON transactions;
CREATE TRIGGER update_transactions_updated_at
    BEFORE UPDATE ON transactions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();