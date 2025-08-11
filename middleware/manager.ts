export default defineNuxtRouteMiddleware((to) => {
  const authStore = useAuthStore()
  
  if (!authStore.isAuthenticated) {
    return navigateTo('/login')
  }
  
  if (!authStore.isManager) {
    throw createError({
      statusCode: 403,
      statusMessage: 'Access denied. Manager role required.'
    })
  }
})