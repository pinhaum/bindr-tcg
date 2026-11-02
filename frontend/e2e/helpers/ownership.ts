import { expect, type Page } from '@playwright/test';

// Registra uma cópia da primeira variante pela API, com o cookie e o token CSRF da sessão da página.
export async function ownOneCopy(page: Page, cardNumber: string) {
	const session = await page.request.get('/api/session');
	expect(session.ok(), 'GET /api/session').toBe(true);
	const { data: auth } = (await session.json()) as {
		data: { csrf_token: string };
	};

	const cardPath = `/api/cards/${encodeURIComponent(cardNumber)}`;
	const detail = await page.request.get(cardPath);
	expect(detail.ok(), `GET ${cardPath}`).toBe(true);
	const { data: card } = (await detail.json()) as {
		data: { variants: { variant_code: string }[] };
	};

	const variant = encodeURIComponent(card.variants[0].variant_code);
	const response = await page.request.post(`${cardPath}/variants/${variant}/increment`, {
		headers: { 'X-CSRF-Token': auth.csrf_token }
	});
	expect(response.ok(), `POST ${cardPath}/variants/${variant}/increment`).toBe(true);
}
