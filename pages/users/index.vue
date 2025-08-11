<template>
  <div>
    <!-- Page header -->
    <div class="sm:flex sm:items-center mb-8">
      <div class="sm:flex-auto">
        <h1 class="text-2xl font-bold text-gray-900">Users</h1>
        <p class="mt-2 text-sm text-gray-700">
          Manage user accounts and roles in the system
        </p>
      </div>
    </div>

    <!-- Loading state -->
    <div v-if="userStore.isLoading" class="flex justify-center py-8">
      <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
    </div>

    <!-- Users table -->
    <div v-else class="bg-white shadow overflow-hidden sm:rounded-md">
      <ul role="list" class="divide-y divide-gray-200">
        <li v-for="user in userStore.users" :key="user.id">
          <div class="px-4 py-4 flex items-center justify-between">
            <div class="flex items-center">
              <div class="flex-shrink-0 h-10 w-10">
                <div class="h-10 w-10 rounded-full bg-primary-100 flex items-center justify-center">
                  <span class="text-primary-600 font-medium text-sm">
                    {{ getInitials(user.full_name || user.email) }}
                  </span>
                </div>
              </div>
              <div class="ml-4">
                <div class="flex items-center">
                  <p class="text-sm font-medium text-gray-900">
                    {{ user.full_name || user.email }}
                  </p>
                  <div class="ml-2 flex space-x-1">
                    <span
                      v-for="role in user.roles"
                      :key="role"
                      :class="getRoleBadgeClass(role)"
                      class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium"
                    >
                      {{ role }}
                    </span>
                  </div>
                </div>
                <p class="text-sm text-gray-500">{{ user.email }}</p>
                <p class="text-xs text-gray-400">Joined {{ formatDate(user.created_at) }}</p>
              </div>
            </div>
            
            <div class="flex items-center space-x-4">
              <div class="text-right">
                <p class="text-sm text-gray-900">
                  {{ getUserTransactionCount(user.id) }} transactions
                </p>
                <p class="text-sm font-medium text-primary-600">
                  Balance: ${{ user.balance?.toFixed(2) || '0.00' }}
                </p>
              </div>
              
              <div class="flex space-x-2">
                <button
                  @click="editUser(user)"
                  class="text-primary-600 hover:text-primary-500"
                >
                  <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                  </svg>
                </button>
              </div>
            </div>
          </div>
        </li>
      </ul>
    </div>

    <!-- Edit User Modal -->
    <UserModal
      v-if="editingUser"
      :user="editingUser"
      @close="editingUser = null"
      @saved="handleUserSaved"
    />
  </div>
</template>

<script setup>
definePageMeta({
  middleware: 'manager'
})

const userStore = useUserStore()
const transactionStore = useTransactionStore()

const editingUser = ref(null)

const getInitials = (name) => {
  return name
    .split(' ')
    .map(word => word[0])
    .join('')
    .toUpperCase()
    .substring(0, 2)
}

const getRoleBadgeClass = (role) => {
  const classes = {
    manager: 'bg-red-100 text-red-800',
    user: 'bg-blue-100 text-blue-800'
  }
  return classes[role] || 'bg-gray-100 text-gray-800'
}

const formatDate = (dateString) => {
  return new Date(dateString).toLocaleDateString()
}

const getUserTransactionCount = (userId) => {
  return transactionStore.transactions.filter(
    t => t.sender_id === userId || t.receiver_id === userId
  ).length
}

const editUser = (user) => {
  editingUser.value = { ...user }
}

const handleUserSaved = () => {
  editingUser.value = null
}

// Fetch data on mount
onMounted(async () => {
  await Promise.all([
    userStore.fetchUsers(),
    transactionStore.fetchTransactions()
  ])
})
</script>