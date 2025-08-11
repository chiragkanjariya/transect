<template>
  <div>
    <!-- Redirect to appropriate page -->
  </div>
</template>

<script setup>
const authStore = useAuthStore()

// Redirect based on auth status
watchEffect(() => {
  if (!authStore.isLoading) {
    if (authStore.isAuthenticated) {
      navigateTo('/dashboard')
    } else {
      navigateTo('/login')
    }
  }
})
</script>