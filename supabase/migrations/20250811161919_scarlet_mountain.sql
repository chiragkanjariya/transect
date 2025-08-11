/*
  # Add Balance Functionality

  1. New Tables
    - `user_balances`
      - `user_id` (uuid, primary key, references user_profiles)
      - `balance` (numeric, default 0.00)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Security
    - Enable RLS on `user_balances` table
    - Add policies for users to view their own balance
    - Add policies for managers to view all balances
    - Add policies for managers to update balances

  3. Functions
    - Function to initialize user balance
    - Function to update balances after transaction
    - Function to validate transaction (sufficient balance)

  4. Triggers
    - Trigger to create initial balance for new users
    - Trigger to update balances when transaction status changes
*/

-- Create user_balances table
CREATE TABLE IF NOT EXISTS user_balances (
  user_id uuid PRIMARY KEY REFERENCES user_profiles(id) ON DELETE CASCADE,
  balance numeric(12,2) DEFAULT 0.00 NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE user_balances ENABLE ROW LEVEL SECURITY;

-- RLS Policies for user_balances
CREATE POLICY "Users can view their own balance"
  ON user_balances
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Managers can view all balances"
  ON user_balances
  FOR SELECT
  TO authenticated
  USING (is_manager(auth.uid()));

CREATE POLICY "Managers can update balances"
  ON user_balances
  FOR UPDATE
  TO authenticated
  USING (is_manager(auth.uid()));

CREATE POLICY "System can insert balances"
  ON user_balances
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Function to create initial balance for new users
CREATE OR REPLACE FUNCTION create_user_balance()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO user_balances (user_id, balance)
  VALUES (NEW.id, 1000.00); -- Give new users $1000 starting balance
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Log error but don't fail the user creation
  RAISE WARNING 'Failed to create user balance: %', SQLERRM;
  RETURN NEW;
END;
$$;

-- Trigger to create balance when user profile is created
DROP TRIGGER IF EXISTS create_user_balance_trigger ON user_profiles;
CREATE TRIGGER create_user_balance_trigger
  AFTER INSERT ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION create_user_balance();

-- Function to validate and process transactions
CREATE OR REPLACE FUNCTION process_transaction()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  sender_balance numeric;
BEGIN
  -- Only process when status changes to 'completed'
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
    -- Check sender's balance
    SELECT balance INTO sender_balance
    FROM user_balances
    WHERE user_id = NEW.sender_id;
    
    -- Validate sufficient balance
    IF sender_balance < NEW.amount THEN
      RAISE EXCEPTION 'Insufficient balance. Available: %, Required: %', sender_balance, NEW.amount;
    END IF;
    
    -- Update sender's balance (subtract)
    UPDATE user_balances
    SET balance = balance - NEW.amount,
        updated_at = now()
    WHERE user_id = NEW.sender_id;
    
    -- Update receiver's balance (add)
    UPDATE user_balances
    SET balance = balance + NEW.amount,
        updated_at = now()
    WHERE user_id = NEW.receiver_id;
    
  -- Handle cancellation - reverse the transaction if it was previously completed
  ELSIF NEW.status = 'cancelled' AND OLD.status = 'completed' THEN
    -- Reverse the transaction
    UPDATE user_balances
    SET balance = balance + NEW.amount,
        updated_at = now()
    WHERE user_id = NEW.sender_id;
    
    UPDATE user_balances
    SET balance = balance - NEW.amount,
        updated_at = now()
    WHERE user_id = NEW.receiver_id;
  END IF;
  
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE EXCEPTION 'Transaction processing failed: %', SQLERRM;
END;
$$;

-- Trigger to process transactions
DROP TRIGGER IF EXISTS process_transaction_trigger ON transactions;
CREATE TRIGGER process_transaction_trigger
  AFTER UPDATE ON transactions
  FOR EACH ROW
  EXECUTE FUNCTION process_transaction();

-- Create balances for existing users
INSERT INTO user_balances (user_id, balance)
SELECT id, 1000.00
FROM user_profiles
WHERE id NOT IN (SELECT user_id FROM user_balances);

-- Add updated_at trigger for user_balances
CREATE TRIGGER update_user_balances_updated_at
  BEFORE UPDATE ON user_balances
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();