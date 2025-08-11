import { defineStore } from 'pinia'
import type { Transaction, CreateTransactionData, UpdateTransactionData, User } from '~/types'

interface TransactionState {
  transactions: Transaction[]
  isLoading: boolean
  users: User[]
}

export const useTransactionStore = defineStore('transactions', {
  state: (): TransactionState => ({
    transactions: [],
    isLoading: false,
    users: []
  }),

  getters: {
    userTransactions: (state) => {
      const authStore = useAuthStore()
      if (authStore.isManager) {
        return state.transactions
      }
      return state.transactions.filter(t => 
        t.sender_id === authStore.user?.id || t.receiver_id === authStore.user?.id
      )
    }
  },

  actions: {
    async fetchTransactions() {
      const { $supabase } = useNuxtApp()
      
      try {
        this.isLoading = true
        const { data, error } = await $supabase
          .from('transactions')
          .select(`
            *,
            sender:user_profiles!sender_id(*),
            receiver:user_profiles!receiver_id(*)
          `)
          .order('created_at', { ascending: false })

        if (error) throw error
        this.transactions = data || []
      } catch (error) {
        console.error('Error fetching transactions:', error)
        throw error
      } finally {
        this.isLoading = false
      }
    },

    async fetchUsers() {
      const { $supabase } = useNuxtApp()
      
      try {
        const { data, error } = await $supabase
          .from('user_profiles')
          .select('*')
          .order('created_at', { ascending: true })

        if (error) throw error
        this.users = data || []
      } catch (error) {
        console.error('Error fetching users:', error)
        throw error
      }
    },

    async createTransaction(transactionData: CreateTransactionData) {
      const { $supabase } = useNuxtApp()
      
      try {
        // Check sender's balance before creating transaction
        const { data: senderBalance, error: balanceError } = await $supabase
          .from('user_balances')
          .select('balance')
          .eq('user_id', transactionData.sender_id)
          .single()

        if (balanceError) throw balanceError
        
        if (senderBalance.balance < transactionData.amount) {
          throw new Error(`Insufficient balance. Available: $${senderBalance.balance}, Required: $${transactionData.amount}`)
        }

        const { data, error } = await $supabase
          .from('transactions')
          .insert(transactionData)
          .select(`
            *,
            sender:user_profiles!sender_id(*),
            receiver:user_profiles!receiver_id(*)
          `)
          .single()

        if (error) throw error
        
        this.transactions.unshift(data)
        return { data, error: null }
      } catch (error: any) {
        console.error('Error creating transaction:', error)
        return { data: null, error: error.message }
      }
    },

    async updateTransaction(id: string, updates: UpdateTransactionData) {
      const { $supabase } = useNuxtApp()
      
      try {
        const { data, error } = await $supabase
          .from('transactions')
          .update(updates)
          .eq('id', id)
          .select(`
            *,
            sender:user_profiles!sender_id(*),
            receiver:user_profiles!receiver_id(*)
          `)
          .single()

        if (error) throw error
        
        const index = this.transactions.findIndex(t => t.id === id)
        if (index !== -1) {
          this.transactions[index] = data
        }
        
        return { data, error: null }
      } catch (error: any) {
        console.error('Error updating transaction:', error)
        return { data: null, error: error.message }
      }
    },

    async deleteTransaction(id: string) {
      const { $supabase } = useNuxtApp()
      
      try {
        const { error } = await $supabase
          .from('transactions')
          .delete()
          .eq('id', id)

        if (error) throw error
        
        this.transactions = this.transactions.filter(t => t.id !== id)
        return { error: null }
      } catch (error: any) {
        console.error('Error deleting transaction:', error)
        return { error: error.message }
      }
    }
  }
})