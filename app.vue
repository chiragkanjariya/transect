<template>
  <div id="app">
    <NuxtLayout>
      <NuxtPage />
    </NuxtLayout>
  </div>
</template>

<script setup>
import { useAuthStore } from '~/stores/auth'

const authStore = useAuthStore()

// Initialize auth on app start
onMounted(async () => {
  await authStore.initialize()
})

// Listen for auth state changes
onMounted(() => {
  const { $supabase } = useNuxtApp()
  
  $supabase.auth.onAuthStateChange(async (event, session) => {
    if (event === 'SIGNED_IN' && session?.user) {
      authStore.user = session.user
      await authStore.fetchProfile()
    } else if (event === 'SIGNED_OUT') {
      authStore.user = null
      authStore.profile = null
    }
  })
})
</script>