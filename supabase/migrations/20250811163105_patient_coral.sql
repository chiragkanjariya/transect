/*
  # Complete Database Schema Setup

  1. New Tables
    - `user_profiles` - User profile information with roles and metadata
    - `user_balances` - User account balances (starting at $1,000)
    - `transactions` - Transaction records between users

  2. Security
    - Enable RLS on all tables
    - Add policies for user access control
    - Manager privileges for administrative functions

  3. Functions & Triggers
    - Automatic user profile creation on signup
    - Balance initialization for new users
    - Transaction processing with balance updates
    - Timestamp management

  4. Indexes
    - Performance optimization for common queries
*/

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
  balance numeric(12,2) NOT NULL DEFAULT 1000.00,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create transactions table
CREATE TABLE IF NOT EXISTS transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id uuid REFERENCES user_profiles(id) ON DELETE CASCADE,
  receiver_id uuid REFERENCES user_profiles(id) ON DELETE CASCADE,
  reason text NOT NULL,
  amount numeric(12,2) NOT NULL CHECK (amount > 0),
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'cancelled')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_email ON user_profiles(email);
CREATE INDEX IF NOT EXISTS idx_transactions_sender_id ON transactions(sender_id);
CREATE INDEX IF NOT EXISTS idx_transactions_receiver_id ON transactions(receiver_id);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at);

-- Enable Row Level Security
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

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to handle new user creation
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_profiles (id, email, full_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create user balance
CREATE OR REPLACE FUNCTION create_user_balance()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_balances (user_id, balance)
  VALUES (NEW.id, 1000.00);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to assign manager role to first user
CREATE OR REPLACE FUNCTION assign_manager_to_first_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Check if this is the first user
  IF (SELECT COUNT(*) FROM user_profiles) = 0 THEN
    NEW.roles = ARRAY['user', 'manager'];
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to process transactions
CREATE OR REPLACE FUNCTION process_transaction()
RETURNS TRIGGER AS $$
BEGIN
  -- Only process when status changes to completed
  IF OLD.status != 'completed' AND NEW.status = 'completed' THEN
    -- Update sender balance (subtract)
    UPDATE user_balances 
    SET balance = balance - NEW.amount 
    WHERE user_id = NEW.sender_id;
    
    -- Update receiver balance (add)
    UPDATE user_balances 
    SET balance = balance + NEW.amount 
    WHERE user_id = NEW.receiver_id;
    
  -- Reverse transaction if status changes from completed to cancelled
  ELSIF OLD.status = 'completed' AND NEW.status = 'cancelled' THEN
    -- Reverse sender balance (add back)
    UPDATE user_balances 
    SET balance = balance + NEW.amount 
    WHERE user_id = NEW.sender_id;
    
    -- Reverse receiver balance (subtract)
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

DROP TRIGGER IF EXISTS assign_manager_trigger ON user_profiles;
CREATE TRIGGER assign_manager_trigger
  BEFORE INSERT ON user_profiles
  FOR EACH ROW EXECUTE FUNCTION assign_manager_to_first_user();

DROP TRIGGER IF EXISTS create_user_balance_trigger ON user_profiles;
CREATE TRIGGER create_user_balance_trigger
  AFTER INSERT ON user_profiles
  FOR EACH ROW EXECUTE FUNCTION create_user_balance();

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

DROP TRIGGER IF EXISTS process_transaction_trigger ON transactions;
CREATE TRIGGER process_transaction_trigger
  AFTER UPDATE ON transactions
  FOR EACH ROW EXECUTE FUNCTION process_transaction();

-- RLS Policies for user_profiles
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON user_profiles;
CREATE POLICY "Public profiles are viewable by everyone"
  ON user_profiles FOR SELECT
  TO public
  USING (true);

DROP POLICY IF EXISTS "Users can insert their own profile" ON user_profiles;
CREATE POLICY "Users can insert their own profile"
  ON user_profiles FOR INSERT
  TO public
  WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
CREATE POLICY "Users can update their own profile"
  ON user_profiles FOR UPDATE
  TO public
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Managers can update all profiles" ON user_profiles;
CREATE POLICY "Managers can update all profiles"
  ON user_profiles FOR UPDATE
  TO public
  USING (is_manager(auth.uid()));

DROP POLICY IF EXISTS "Managers can delete any profile" ON user_profiles;
CREATE POLICY "Managers can delete any profile"
  ON user_profiles FOR DELETE
  TO public
  USING (is_manager(auth.uid()));

-- RLS Policies for user_balances
DROP POLICY IF EXISTS "Users can view their own balance" ON user_balances;
CREATE POLICY "Users can view their own balance"
  ON user_balances FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Managers can view all balances" ON user_balances;
CREATE POLICY "Managers can view all balances"
  ON user_balances FOR SELECT
  TO authenticated
  USING (is_manager(auth.uid()));

DROP POLICY IF EXISTS "System can insert balances" ON user_balances;
CREATE POLICY "System can insert balances"
  ON user_balances FOR INSERT
  TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "Managers can update balances" ON user_balances;
CREATE POLICY "Managers can update balances"
  ON user_balances FOR UPDATE
  TO authenticated
  USING (is_manager(auth.uid()));

-- RLS Policies for transactions
DROP POLICY IF EXISTS "Users can view their own transactions" ON transactions;
CREATE POLICY "Users can view their own transactions"
  ON transactions FOR SELECT
  TO public
  USING (
    auth.uid() = sender_id OR 
    auth.uid() = receiver_id OR 
    is_manager(auth.uid())
  );

DROP POLICY IF EXISTS "Managers can insert transactions" ON transactions;
CREATE POLICY "Managers can insert transactions"
  ON transactions FOR INSERT
  TO public
  WITH CHECK (is_manager(auth.uid()));

DROP POLICY IF EXISTS "Managers can update transactions" ON transactions;
CREATE POLICY "Managers can update transactions"
  ON transactions FOR UPDATE
  TO public
  USING (is_manager(auth.uid()));

DROP POLICY IF EXISTS "Managers can delete transactions" ON transactions;
CREATE POLICY "Managers can delete transactions"
  ON transactions FOR DELETE
  TO public
  USING (is_manager(auth.uid()));