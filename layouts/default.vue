<template>
  <div class="min-h-screen bg-gray-50">
    <!-- Loading screen -->
    <div v-if="authStore.isLoading" class="min-h-screen flex items-center justify-center">
      <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
    </div>
    
    <!-- Auth layout -->
    <div v-else-if="!authStore.isAuthenticated">
      <slot />
    </div>
    
    <!-- Main app layout -->
    <div v-else class="flex h-screen">
      <!-- Sidebar -->
      <div class="hidden md:flex md:flex-shrink-0">
        <div class="flex flex-col w-64">
          <div class="flex flex-col flex-grow pt-5 pb-4 overflow-y-auto bg-white border-r border-gray-200">
            <div class="flex items-center flex-shrink-0 px-4">
              <h1 class="text-xl font-bold text-gray-900">Transaction Manager</h1>
            </div>
            
            <div class="mt-5 flex-grow flex flex-col">
              <nav class="flex-1 px-2 space-y-1">
                <NuxtLink
                  to="/dashboard"
                  class="text-gray-900 hover:bg-gray-100 group flex items-center px-2 py-2 text-sm font-medium rounded-md"
                  :class="{ 'bg-gray-100': $route.path === '/dashboard' }"
                >
                  <svg class="text-gray-500 mr-3 h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2H5a2 2 0 00-2-2z" />
                  </svg>
                  Dashboard
                </NuxtLink>
                
                <NuxtLink
                  to="/transactions"
                  class="text-gray-900 hover:bg-gray-100 group flex items-center px-2 py-2 text-sm font-medium rounded-md"
                  :class="{ 'bg-gray-100': $route.path.startsWith('/transactions') }"
                >
                  <svg class="text-gray-500 mr-3 h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4" />
                  </svg>
                  Transactions
                </NuxtLink>
                
                <NuxtLink
                  v-if="authStore.isManager"
                  to="/users"
                  class="text-gray-900 hover:bg-gray-100 group flex items-center px-2 py-2 text-sm font-medium rounded-md"
                  :class="{ 'bg-gray-100': $route.path.startsWith('/users') }"
                >
                  <svg class="text-gray-500 mr-3 h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z" />
                  </svg>
                  Users
                </NuxtLink>
              </nav>
            </div>
          </div>
        </div>
      </div>
      
      <!-- Main content -->
      <div class="flex flex-col w-0 flex-1 overflow-hidden">
        <!-- Top bar -->
        <div class="relative z-10 flex-shrink-0 flex h-16 bg-white shadow">
          <div class="flex-1 px-4 flex justify-between">
            <div class="flex-1 flex">
              <!-- Mobile menu button -->
              <button 
                @click="toggleMobileMenu"
                class="px-4 border-r border-gray-200 text-gray-500 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-primary-500 md:hidden"
              >
                <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
                </svg>
              </button>
            </div>
            
            <div class="ml-4 flex items-center md:ml-6">
              <!-- Profile dropdown -->
              <div class="ml-3 relative">
                <div class="flex items-center space-x-4">
                  <div class="text-sm">
                    <p class="text-gray-700">{{ authStore.profile?.full_name || authStore.user?.email }}</p>
                    <p class="text-xs text-gray-500 capitalize">{{ authStore.profile?.roles?.join(', ') }}</p>
                  </div>
                  <button
                    @click="authStore.signOut"
                    class="bg-red-600 hover:bg-red-700 text-white text-sm px-3 py-1 rounded-md transition-colors duration-200"
                  >
                    Sign Out
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
        
        <!-- Page content -->
        <main class="flex-1 relative overflow-y-auto focus:outline-none">
          <div class="py-6">
            <div class="max-w-7xl mx-auto px-4 sm:px-6 md:px-8">
              <slot />
            </div>
          </div>
        </main>
      </div>
      
      <!-- Mobile menu -->
      <div v-if="mobileMenuOpen" class="md:hidden">
        <div class="fixed inset-0 flex z-40">
          <div class="fixed inset-0" @click="mobileMenuOpen = false">
            <div class="absolute inset-0 bg-gray-600 opacity-75"></div>
          </div>
          
          <div class="relative flex-1 flex flex-col max-w-xs w-full pt-5 pb-4 bg-white">
            <div class="absolute top-0 right-0 -mr-12 pt-2">
              <button
                @click="mobileMenuOpen = false"
                class="ml-1 flex items-center justify-center h-10 w-10 rounded-full focus:outline-none focus:ring-2 focus:ring-inset focus:ring-white"
              >
                <svg class="h-6 w-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            
            <div class="flex-shrink-0 flex items-center px-4">
              <h1 class="text-xl font-bold text-gray-900">Transaction Manager</h1>
            </div>
            
            <div class="mt-5 flex-1 h-0 overflow-y-auto">
              <nav class="px-2 space-y-1">
                <NuxtLink
                  to="/dashboard"
                  @click="mobileMenuOpen = false"
                  class="text-gray-900 hover:bg-gray-100 group flex items-center px-2 py-2 text-base font-medium rounded-md"
                >
                  Dashboard
                </NuxtLink>
                <NuxtLink
                  to="/transactions"
                  @click="mobileMenuOpen = false"
                  class="text-gray-900 hover:bg-gray-100 group flex items-center px-2 py-2 text-base font-medium rounded-md"
                >
                  Transactions
                </NuxtLink>
                <NuxtLink
                  v-if="authStore.isManager"
                  to="/users"
                  @click="mobileMenuOpen = false"
                  class="text-gray-900 hover:bg-gray-100 group flex items-center px-2 py-2 text-base font-medium rounded-md"
                >
                  Users
                </NuxtLink>
              </nav>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
const authStore = useAuthStore()
const mobileMenuOpen = ref(false)

const toggleMobileMenu = () => {
  mobileMenuOpen.value = !mobileMenuOpen.value
}
</script>