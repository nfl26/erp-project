import { test, expect } from '@playwright/test'

test.describe('Smoke tests — portal ERP', () => {
  test('home carga con status 200 y tiene h1 visible', async ({ page }) => {
    const response = await page.goto('/')
    expect(response?.status()).toBe(200)
    await expect(page.locator('h1')).toBeVisible()
  })

  test('health endpoint retorna status ok con timestamp y version', async ({ request }) => {
    const response = await request.get('/api/health')
    expect(response.status()).toBe(200)
    const body = await response.json()
    expect(body).toMatchObject({ status: 'ok' })
    expect(typeof body.timestamp).toBe('string')
    expect(typeof body.version).toBe('string')
  })
})
