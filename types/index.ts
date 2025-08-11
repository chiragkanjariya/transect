export interface User {
  id: string
  email: string
  full_name?: string
  roles: string[]
  created_at: string
  updated_at: string
  balance?: number
}

export interface Transaction {
  id: string
  sender_id: string
  receiver_id: string
  reason: string
  amount: number
  status: 'pending' | 'completed' | 'cancelled'
  created_at: string
  updated_at: string
  sender?: User
  receiver?: User
}

export interface AuthUser {
  id: string
  email: string
  user_metadata?: Record<string, any>
}

export interface CreateTransactionData {
  sender_id: string
  receiver_id: string
  reason: string
  amount: number
  status?: 'pending' | 'completed' | 'cancelled'
}

export interface UpdateTransactionData {
  reason?: string
  amount?: number
  status?: 'pending' | 'completed' | 'cancelled'
}