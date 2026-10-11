const CURRENCY_UNITS: Record<string, string> = { USD: 'US$' };

const decimal = new Intl.NumberFormat('pt-BR', {
	minimumFractionDigits: 2,
	maximumFractionDigits: 2
});

const observedDate = new Intl.DateTimeFormat('pt-BR', {
	timeZone: 'America/Sao_Paulo',
	day: '2-digit',
	month: '2-digit',
	year: 'numeric'
});

export function formatPrice(amount: string, currency: string): string {
	return `${CURRENCY_UNITS[currency] ?? currency} ${decimal.format(Number(amount))}`;
}

export function formatObservedDate(iso: string): string {
	return observedDate.format(new Date(iso));
}

export function copies(n: number): string {
	return n === 1 ? '1 cópia' : `${n} cópias`;
}
