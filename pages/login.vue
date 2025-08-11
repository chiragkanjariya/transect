<template>
  <div class="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
    <div class="max-w-md w-full space-y-8">
      <div>
        <h2 class="mt-6 text-center text-3xl font-extrabold text-gray-900">
          {{ isSignUp ? 'Create your account' : 'Sign in to your account' }}
        </h2>
        <p class="mt-2 text-center text-sm text-gray-600">
          {{ isSignUp ? 'Already have an account?' : 'Don\'t have an account?' }}
          <button
            @click="isSignUp = !isSignUp"
            class="font-medium text-primary-600 hover:text-primary-500"
          >
            {{ isSignUp ? 'Sign in' : 'Sign up' }}
          </button>
        </p>
      </div>
      
      <form class="mt-8 space-y-6" @submit.prevent="handleSubmit">
        <input type="hidden" name="remember" value="true">
        <div class="rounded-md shadow-sm space-y-4">
          <div v-if="isSignUp">
            <label for="full-name" class="block text-sm font-medium text-gray-700">Full Name</label>
            <input
              id="full-name"
              v-model="form.fullName"
              name="full-name"
              type="text"
              required
              class="form-input"
              placeholder="Full name"
            >
          </div>
          
          <div>
            <label for="email-address" class="block text-sm font-medium text-gray-700">Email Address</label>
            <input
              id="email-address"
              v-model="form.email"
              name="email"
              type="email"
              autocomplete="email"
              required
              class="form-input"
              placeholder="Email address"
            >
          </div>
          
          <div>
            <label for="password" class="block text-sm font-medium text-gray-700">Password</label>
            <input
              id="password"
              v-model="form.password"
              name="password"
              type="password"
              autocomplete="current-password"
              required
              class="form-input"
              placeholder="Password"
            >
          </div>
        </div>

        <div v-if="error" class="text-red-600 text-sm">
          {{ error }}
        </div>

        <div>
          <button
            type="submit"
            :disabled="isLoading"
            class="group relative w-full btn-primary disabled:opacity-50"
          >
            <span v-if="isLoading" class="absolute left-0 inset-y-0 flex items-center pl-3">
              <div class="animate-spin rounded-full h-5 w-5 border-b-2 border-white"></div>
            </span>
            {{ isSignUp ? 'Sign up' : 'Sign in' }}
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<script setup>
definePageMeta({
  layout: false
})

const authStore = useAuthStore()
const router = useRouter()

const isSignUp = ref(false)
const isLoading = ref(false)
const error = ref('')

const form = reactive({
  email: '',
  password: '',
  fullName: ''
})

const handleSubmit = async () => {
  if (isLoading.value) return
  
  // Client-side validation
  if (form.password.length < 6) {
    error.value = 'Password must be at least 6 characters long'
    return
  }
  
  if (isSignUp.value && form.fullName.trim().length < 2) {
    error.value = 'Full name must be at least 2 characters long'
    return
  }
  
  isLoading.value = true
  error.value = ''
  
  try {
    let result
    
    if (isSignUp.value) {
      result = await authStore.signUp(form.email, form.password, form.fullName)
    } else {
      result = await authStore.signIn(form.email, form.password)
    }
    
    if (result.error) {
      // Provide user-friendly error messages
      if (result.error.includes('weak_password')) {
        error.value = 'Password must be at least 6 characters long'
      } else if (result.error.includes('Invalid login credentials')) {
        error.value = 'Invalid email or password'
      } else if (result.error.includes('User already registered')) {
        error.value = 'An account with this email already exists'
      } else if (result.error.includes('Database error')) {
        error.value = 'Account creation failed. Please try again or contact support.'
      } else {
        error.value = result.error
      }
    } else {
      await router.push('/dashboard')
    }
  } catch (err) {
    error.value = 'An unexpected error occurred'
    console.error('Auth error:', err)
  } finally {
    isLoading.value = false
  }
}

// Redirect if already authenticated
watchEffect(() => {
  if (authStore.isAuthenticated) {
    router.push('/dashboard')
  }
})
</script>