<template>
  <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
    <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
      <div class="mt-3">
        <h3 class="text-lg font-medium text-gray-900 mb-4">
          {{ transaction ? 'Edit Transaction' : 'Create Transaction' }}
        </h3>
        
        <form @submit.prevent="handleSubmit" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700">Sender</label>
            <select v-model="form.sender_id" required class="form-input">
              <option value="">Select sender</option>
              <option v-for="user in transactionStore.users" :key="user.id" :value="user.id">
                {{ user.full_name || user.email }}
              </option>
            </select>
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700">Receiver</label>
            <select v-model="form.receiver_id" required class="form-input">
              <option value="">Select receiver</option>
              <option v-for="user in transactionStore.users" :key="user.id" :value="user.id">
                {{ user.full_name || user.email }}
              </option>
            </select>
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700">Amount</label>
            <input
              v-model.number="form.amount"
              type="number"
              step="0.01"
              min="0.01"
              required
              class="form-input"
              placeholder="0.00"
            >
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700">Reason</label>
            <textarea
              v-model="form.reason"
              required
              rows="3"
              class="form-input"
              placeholder="Enter transaction reason..."
            ></textarea>
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700">Status</label>
            <select v-model="form.status" required class="form-input">
              <option value="pending">Pending</option>
              <option value="completed">Completed</option>
              <option value="cancelled">Cancelled</option>
            </select>
          </div>
          
          <div v-if="error" class="text-red-600 text-sm">
            {{ error }}
          </div>
          
          <div class="flex space-x-3 pt-4">
            <button
              type="submit"
              :disabled="isLoading"
              class="btn-primary flex-1"
            >
              <span v-if="isLoading" class="mr-2">
                <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white inline-block"></div>
              </span>
              {{ transaction ? 'Update' : 'Create' }}
            </button>
            <button
              type="button"
              @click="$emit('close')"
              class="btn-secondary flex-1"
            >
              Cancel
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup>
const props = defineProps({
  transaction: {
    type: Object,
    default: null
  }
})

const emit = defineEmits(['close', 'saved'])

const transactionStore = useTransactionStore()
const isLoading = ref(false)
const error = ref('')

const form = reactive({
  sender_id: props.transaction?.sender_id || '',
  receiver_id: props.transaction?.receiver_id || '',
  amount: props.transaction?.amount || 0,
  reason: props.transaction?.reason || '',
  status: props.transaction?.status || 'pending'
})

const handleSubmit = async () => {
  if (isLoading.value) return
  
  isLoading.value = true
  error.value = ''
  
  try {
    let result
    
    if (props.transaction) {
      // Update existing transaction
      result = await transactionStore.updateTransaction(props.transaction.id, {
        reason: form.reason,
        amount: form.amount,
        status: form.status
      })
    } else {
      // Create new transaction
      result = await transactionStore.createTransaction(form)
    }
    
    if (result.error) {
      error.value = result.error
    } else {
      emit('saved')
    }
  } catch (err) {
    error.value = 'An unexpected error occurred'
    console.error('Transaction modal error:', err)
  } finally {
    isLoading.value = false
  }
}
</script>