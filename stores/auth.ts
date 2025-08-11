import { defineStore } from 'pinia'
import type { User, AuthUser } from '~/types'

interface AuthState {
  user: AuthUser | null
  profile: User | null
  isLoading: boolean
}

export const useAuthStore = defineStore('auth', {
  state: (): AuthState => ({
    user: null,
    profile: null,
    isLoading: true
  }),

  getters: {
    isAuthenticated: (state) => !!state.user,
    isManager: (state) => state.profile?.roles?.includes('manager') ?? false,
    isUser: (state) => state.profile?.roles?.includes('user') ?? false
  },

  actions: {
    async initialize() {
      const { $supabase } = useNuxtApp()
      
      try {
        this.isLoading = true
        const { data: { session } } = await $supabase.auth.getSession()
        
        if (session?.user) {
          this.user = session.user
          await this.fetchProfile()
        }
      } catch (error) {
        console.error('Auth initialization error:', error)
      } finally {
        this.isLoading = false
      }
    },

    async fetchProfile() {
      if (!this.user) return

      const { $supabase } = useNuxtApp()
      
      try {
        const { data, error } = await $supabase
          .from('user_profiles')
          .select(`
            *,
            user_balances(balance)
          `)
          .eq('id', this.user.id)
          .single()

        if (error) throw error
        this.profile = {
          ...data,
          balance: data.user_balances?.[0]?.balance || 0
        }
      } catch (error) {
        console.error('Error fetching profile:', error)
      }
    },

    async signUp(email: string, password: string, fullName: string) {
      const { $supabase } = useNuxtApp()
      
      try {
        const { data, error } = await $supabase.auth.signUp({
          email,
          password,
          options: {
            data: {
              full_name: fullName
            }
          }
        })

        if (error) throw error

        if (data.user) {
          this.user = data.user
          // Wait a bit for the trigger to create the profile
          setTimeout(() => this.fetchProfile(), 1000)
        }

        return { data, error: null }
      } catch (error: any) {
        return { data: null, error: error.message }
      }
    },

    async signIn(email: string, password: string) {
      const { $supabase } = useNuxtApp()
      
      try {
        const { data, error } = await $supabase.auth.signInWithPassword({
          email,
          password
        })

        if (error) throw error

        if (data.user) {
          this.user = data.user
          await this.fetchProfile()
        }

        return { data, error: null }
      } catch (error: any) {
        return { data: null, error: error.message }
      }
    },

    async signOut() {
      const { $supabase } = useNuxtApp()
      
      try {
        const { error } = await $supabase.auth.signOut()
        if (error) throw error

        this.user = null
        this.profile = null
        
        await navigateTo('/login')
      } catch (error) {
        console.error('Sign out error:', error)
      }
    }
  }
})