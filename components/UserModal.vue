<template>
  <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
    <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
      <div class="mt-3">
        <h3 class="text-lg font-medium text-gray-900 mb-4">
          Edit User
        </h3>
        
        <form @submit.prevent="handleSubmit" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700">Full Name</label>
            <input
              v-model="form.full_name"
              type="text"
              class="form-input"
              placeholder="Enter full name"
            >
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700">Email</label>
            <input
              v-model="form.email"
              type="email"
              readonly
              class="form-input bg-gray-50"
            >
            <p class="text-xs text-gray-500 mt-1">Email cannot be changed</p>
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700">Roles</label>
            <div class="mt-2 space-y-2">
              <label class="inline-flex items-center">
                <input
                  v-model="form.roles"
                  type="checkbox"
                  value="user"
                  class="rounded border-gray-300 text-primary-600 shadow-sm focus:border-primary-300 focus:ring focus:ring-primary-200 focus:ring-opacity-50"
                >
                <span class="ml-2 text-sm text-gray-700">User</span>
              </label>
              <label class="inline-flex items-center">
                <input
                  v-model="form.roles"
                  type="checkbox"
                  value="manager"
                  class="rounded border-gray-300 text-primary-600 shadow-sm focus:border-primary-300 focus:ring focus:ring-primary-200 focus:ring-opacity-50"
                >
                <span class="ml-2 text-sm text-gray-700">Manager</span>
              </label>
            </div>
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
              Update
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
  user: {
    type: Object,
    required: true
  }
})

const emit = defineEmits(['close', 'saved'])

const userStore = useUserStore()
const isLoading = ref(false)
const error = ref('')

const form = reactive({
  full_name: props.user?.full_name || '',
  email: props.user?.email || '',
  roles: [...(props.user?.roles || [])]
})

const handleSubmit = async () => {
  if (isLoading.value) return
  
  // Ensure at least one role is selected
  if (form.roles.length === 0) {
    error.value = 'At least one role must be selected'
    return
  }
  
  isLoading.value = true
  error.value = ''
  
  try {
    const result = await userStore.updateUser(props.user.id, {
      full_name: form.full_name,
      roles: form.roles
    })
    
    if (result.error) {
      error.value = result.error
    } else {
      emit('saved')
    }
  } catch (err) {
    error.value = 'An unexpected error occurred'
    console.error('User modal error:', err)
  } finally {
    isLoading.value = false
  }
}
</script>