<template>
  <div>
    <!-- Page header -->
    <div class="sm:flex sm:items-center mb-8">
      <div class="sm:flex-auto">
        <h1 class="text-2xl font-bold text-gray-900">Transactions</h1>
        <p class="mt-2 text-sm text-gray-700">
          {{ authStore.isManager ? 'Manage all transactions in the system' : 'View your transaction history' }}
        </p>
      </div>
      <div v-if="authStore.isManager" class="mt-4 sm:mt-0 sm:ml-16 sm:flex-none">
        <button
          @click="showCreateModal = true"
          class="btn-primary"
        >
          Create Transaction
        </button>
      </div>
    </div>

    <!-- Filters -->
    <div class="mb-6 grid grid-cols-1 gap-4 sm:grid-cols-3">
      <div>
        <label class="block text-sm font-medium text-gray-700">Status</label>
        <select v-model="filters.status" class="form-input">
          <option value="">All Status</option>
          <option value="pending">Pending</option>
          <option value="completed">Completed</option>
          <option value="cancelled">Cancelled</option>
        </select>
      </div>
      
      <div>
        <label class="block text-sm font-medium text-gray-700">Search</label>
        <input
          v-model="filters.search"
          type="text"
          placeholder="Search by reason or user..."
          class="form-input"
        >
      </div>
      
      <div>
        <label class="block text-sm font-medium text-gray-700">Sort By</label>
        <select v-model="filters.sortBy" class="form-input">
          <option value="created_at">Date Created</option>
          <option value="amount">Amount</option>
          <option value="status">Status</option>
        </select>
      </div>
    </div>

    <!-- Loading state -->
    <div v-if="transactionStore.isLoading" class="flex justify-center py-8">
      <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
    </div>

    <!-- Empty state -->
    <div v-else-if="filteredTransactions.length === 0" class="text-center py-12">
      <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4" />
      </svg>
      <h3 class="mt-2 text-sm font-medium text-gray-900">No transactions</h3>
      <p class="mt-1 text-sm text-gray-500">
        {{ authStore.isManager ? 'Get started by creating a new transaction.' : 'No transactions found matching your criteria.' }}
      </p>
    </div>

    <!-- Transactions table -->
    <div v-else class="bg-white shadow overflow-hidden sm:rounded-md">
      <ul role="list" class="divide-y divide-gray-200">
        <li v-for="transaction in filteredTransactions" :key="transaction.id">
          <div class="px-4 py-4 flex items-center justify-between">
            <div class="flex items-center">
              <div class="flex-shrink-0 h-10 w-10">
                <div class="h-10 w-10 rounded-full bg-gray-100 flex items-center justify-center">
                  <svg class="h-5 w-5 text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4" />
                  </svg>
                </div>
              </div>
              <div class="ml-4">
                <div class="flex items-center">
                  <p class="text-sm font-medium text-gray-900 truncate">
                    {{ transaction.sender?.full_name || transaction.sender?.email }}
                  </p>
                  <svg class="flex-shrink-0 mx-2 h-4 w-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                  </svg>
                  <p class="text-sm font-medium text-gray-900 truncate">
                    {{ transaction.receiver?.full_name || transaction.receiver?.email }}
                  </p>
                </div>
                <p class="text-sm text-gray-500">{{ transaction.reason }}</p>
                <p class="text-xs text-gray-400">{{ formatDate(transaction.created_at) }}</p>
              </div>
            </div>
            
            <div class="flex items-center space-x-4">
              <div class="text-right">
                <p :class="getAmountColor(transaction)" class="text-sm font-medium">
                  {{ formatAmount(transaction) }}
                </p>
                <span :class="getStatusBadgeClass(transaction.status)" class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium">
                  {{ transaction.status }}
                </span>
              </div>
              
              <div v-if="authStore.isManager" class="flex space-x-2">
                <button
                  v-if="transaction.status === 'pending'"
                  @click="completeTransaction(transaction)"
                  class="text-green-600 hover:text-green-500"
                  title="Complete Transaction"
                >
                  <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </button>
                <button
                  v-if="transaction.status === 'pending'"
                  @click="cancelTransaction(transaction)"
                  class="text-red-600 hover:text-red-500"
                  title="Cancel Transaction"
                >
                  <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>
            </div>
          </div>
        </li>
      </ul>
    </div>

    <!-- Create Transaction Modal -->
    <TransactionModal
      v-if="showCreateModal"
      @close="showCreateModal = false"
      @saved="handleTransactionSaved"
    />
  </div>
</template>

<script setup>
definePageMeta({
  middleware: 'auth'
})

const authStore = useAuthStore()
const transactionStore = useTransactionStore()

const showCreateModal = ref(false)

const filters = reactive({
  status: '',
  search: '',
  sortBy: 'created_at'
})

const filteredTransactions = computed(() => {
  let transactions = [...transactionStore.userTransactions]
  
  // Filter by status
  if (filters.status) {
    transactions = transactions.filter(t => t.status === filters.status)
  }
  
  // Filter by search
  if (filters.search) {
    const search = filters.search.toLowerCase()
    transactions = transactions.filter(t =>
      t.reason.toLowerCase().includes(search) ||
      t.sender?.full_name?.toLowerCase().includes(search) ||
      t.sender?.email?.toLowerCase().includes(search) ||
      t.receiver?.full_name?.toLowerCase().includes(search) ||
      t.receiver?.email?.toLowerCase().includes(search)
    )
  }
  
  // Sort
  transactions.sort((a, b) => {
    if (filters.sortBy === 'created_at') {
      return new Date(b.created_at) - new Date(a.created_at)
    } else if (filters.sortBy === 'amount') {
      return Math.abs(b.amount) - Math.abs(a.amount)
    } else if (filters.sortBy === 'status') {
      return a.status.localeCompare(b.status)
    }
    return 0
  })
  
  return transactions
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

const completeTransaction = async (transaction) => {
  if (!confirm('Are you sure you want to complete this transaction?')) {
    return
  }
  
  try {
    const { error } = await transactionStore.updateTransaction(transaction.id, {
      status: 'completed'
    })
    if (error) {
      alert('Error completing transaction: ' + error)
    } else {
      // Refresh user data to update balances
      await Promise.all([
        transactionStore.fetchUsers(),
        useAuthStore().fetchProfile()
      ])
    }
  } catch (error) {
    console.error('Error completing transaction:', error)
    alert('Error completing transaction')
  }
}

const cancelTransaction = async (transaction) => {
  if (!confirm('Are you sure you want to cancel this transaction?')) {
    return
  }
  
  try {
    const { error } = await transactionStore.updateTransaction(transaction.id, {
      status: 'cancelled'
    })
    if (error) {
      alert('Error cancelling transaction: ' + error)
    }
  } catch (error) {
    console.error('Error cancelling transaction:', error)
    alert('Error cancelling transaction')
  }
}

const handleTransactionSaved = () => {
  showCreateModal.value = false
}

// Fetch data on mount
onMounted(async () => {
  await Promise.all([
    transactionStore.fetchTransactions(),
    transactionStore.fetchUsers()
  ])
})
</script>