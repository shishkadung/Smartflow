import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [react()],
  server: {
    host: true,
    port: 5173,
    proxy: {
      '/smartflow-api': {
        target: 'http://127.0.0.1',
        changeOrigin: true,
        rewrite: (path) => {
          const q = path.indexOf('?')
          const pathname = q === -1 ? path : path.slice(0, q)
          const search = q === -1 ? '' : path.slice(q)
          return pathname.replace(/^\/smartflow-api/, '/Smartflow/backend/backend/api') + search
        },
        configure: (proxy) => {
          proxy.on('proxyReq', (proxyReq, req) => {
            const raw = req.headers['x-smartflow-token']
            const auth = req.headers.authorization
            if (raw) proxyReq.setHeader('X-Smartflow-Token', raw)
            if (auth) proxyReq.setHeader('Authorization', auth)
            if (req.headers['x-authorization']) {
              proxyReq.setHeader('X-Authorization', req.headers['x-authorization'])
            }
          })
        },
      },
    },
  },
})
