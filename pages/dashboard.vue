<template>
  <div>
    <!-- Page header -->
    <div class="mb-8">
      <h1 class="text-2xl font-bold text-gray-900">Dashboard</h1>
      <p class="mt-1 text-sm text-gray-600">
        Welcome back, {{ authStore.profile?.full_name || authStore.user?.email }}
      </p>
      <div class="mt-2 text-lg font-semibold text-primary-600">
        Balance: ${{ authStore.profile?.balance?.toFixed(2) || '0.00' }}
      </div>
    </div>

    <!-- Stats -->
    <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4 mb-8">
      <!-- Total Transactions -->
      <div class="bg-white overflow-hidden shadow rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <svg class="h-6 w-6 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4" />
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Total Transactions</dt>
                <dd class="text-lg font-medium text-gray-900">{{ stats.totalTransactions }}</dd>
              </dl>
            </div>
          </div>
        </div>
      </div>

      <!-- Pending -->
      <div class="bg-white overflow-hidden shadow rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <svg class="h-6 w-6 text-yellow-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Pending</dt>
                <dd class="text-lg font-medium text-gray-900">{{ stats.pendingTransactions }}</dd>
              </dl>
            </div>
          </div>
        </div>
      </div>

      <!-- Completed -->
      <div class="bg-white overflow-hidden shadow rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <svg class="h-6 w-6 text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Completed</dt>
                <dd class="text-lg font-medium text-gray-900">{{ stats.completedTransactions }}</dd>
              </dl>
            </div>
          </div>
        </div>
      </div>

      <!-- Total Users (Manager only) -->
      <div v-if="authStore.isManager" class="bg-white overflow-hidden shadow rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <svg class="h-6 w-6 text-blue-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z" />
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Total Users</dt>
                <dd class="text-lg font-medium text-gray-900">{{ stats.totalUsers }}</dd>
              </dl>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Recent Transactions -->
    <div class="bg-white shadow rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg leading-6 font-medium text-gray-900">Recent Transactions</h3>
          <NuxtLink
            to="/transactions"
            class="text-sm text-primary-600 hover:text-primary-500"
          >
            View all
          </NuxtLink>
        </div>
        
        <div v-if="transactionStore.isLoading" class="flex justify-center py-4">
          <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
        </div>
        
        <div v-else-if="recentTransactions.length === 0" class="text-gray-500 text-center py-4">
          No transactions found
        </div>
        
        <div v-else class="flow-root">
          <ul role="list" class="-mb-8">
            <li v-for="(transaction, idx) in recentTransactions" :key="transaction.id">
              <div class="relative pb-8" :class="{ 'pb-0': idx === recentTransactions.length - 1 }">
                <div v-if="idx !== recentTransactions.length - 1" class="absolute top-5 left-5 -ml-px h-full w-0.5 bg-gray-200"></div>
                <div class="relative flex items-start space-x-3">
                  <div class="relative px-1">
                    <div class="h-8 w-8 bg-gray-100 rounded-full ring-8 ring-white flex items-center justify-center">
                      <svg class="h-4 w-4 text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4" />
                      </svg>
                    </div>
                  </div>
                  <div class="min-w-0 flex-1">
                    <div class="flex items-center justify-between">
                      <p class="text-sm text-gray-900">
                        <span class="font-medium">{{ transaction.sender?.full_name || transaction.sender?.email }}</span>
                        →
                        <span class="font-medium">{{ transaction.receiver?.full_name || transaction.receiver?.email }}</span>
                      </p>
                      <div class="text-right text-sm">
                        <p :class="getAmountColor(transaction)" class="font-medium">
                          {{ formatAmount(transaction) }}
                        </p>
                        <p class="text-gray-500">{{ formatDate(transaction.created_at) }}</p>
                      </div>
                    </div>
                    <div class="mt-2 text-sm text-gray-700">
                      <p>{{ transaction.reason }}</p>
                      <span :class="getStatusBadgeClass(transaction.status)" class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium mt-1">
                        {{ transaction.status }}
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            </li>
          </ul>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
definePageMeta({
  middleware: 'auth'
})

const authStore = useAuthStore()
const transactionStore = useTransactionStore()

const stats = computed(() => {
  const transactions = transactionStore.userTransactions
  return {
    totalTransactions: transactions.length,
    pendingTransactions: transactions.filter(t => t.status === 'pending').length,
    completedTransactions: transactions.filter(t => t.status === 'completed').length,
    totalUsers: transactionStore.users.length
  }
})

const recentTransactions = computed(() => {
  return transactionStore.userTransactions.slice(0, 5)
})

const getAmountColor = (transaction) => {
  const isReceiver = transaction.receiver_id === authStore.user?.id
  return isReceiver ? 'text-green-600' : 'text-red-600'
}

const formatAmount = (transaction) => {
  const isReceiver = transaction.receiver_id === authStore.user?.id
  const prefix = isReceiver ? '+' : '-'
  return `${prefix}$${Math.abs(transaction.amount).toFixed(2)}`
}

const formatDate = (dateString) => {
  return new Date(dateString).toLocaleDateString()
}

const getStatusBadgeClass = (status) => {
  const classes = {
    pending: 'bg-yellow-100 text-yellow-800',
    completed: 'bg-green-100 text-green-800',
    cancelled: 'bg-red-100 text-red-800'
  }
  return classes[status] || 'bg-gray-100 text-gray-800'
}

// Fetch data on mount
onMounted(async () => {
  await Promise.all([
    transactionStore.fetchTransactions(),
    transactionStore.fetchUsers()
  ])
})
</script>