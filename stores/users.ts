import { defineStore } from 'pinia'
import type { User } from '~/types'

interface UserState {
  users: User[]
  isLoading: boolean
}

export const useUserStore = defineStore('users', {
  state: (): UserState => ({
    users: [],
    isLoading: false
  }),

  actions: {
    async fetchUsers() {
      const { $supabase } = useNuxtApp()
      
      try {
        this.isLoading = true
        const { data, error } = await $supabase
          .from('user_profiles')
          .select('*')
          .order('created_at', { ascending: true })

        if (error) throw error
        this.users = data || []
      } catch (error) {
        console.error('Error fetching users:', error)
        throw error
      } finally {
        this.isLoading = false
      }
    },

    async updateUser(id: string, updates: Partial<User>) {
      const { $supabase } = useNuxtApp()
      
      try {
        const { data, error } = await $supabase
          .from('user_profiles')
          .update(updates)
          .eq('id', id)
          .select('*')
          .single()

        if (error) throw error
        
        const index = this.users.findIndex(u => u.id === id)
        if (index !== -1) {
          this.users[index] = data
        }
        
        return { data, error: null }
      } catch (error: any) {
        console.error('Error updating user:', error)
        return { data: null, error: error.message }
      }
    }
  }
})