import { resolve } from '$app/paths';

const hasControlCharacter = (value: string) =>
	[...value].some((char) => char.charCodeAt(0) < 0x20 || char.charCodeAt(0) === 0x7f);

const hasDotSegment = (raw: string) =>
	raw
		.split(/[?#]/, 1)[0]
		.split('/')
		.some((segment) => {
			const decoded = decodeURIComponent(segment);
			return decoded === '.' || decoded === '..';
		});

// URLs antigas da SPA carregavam o prefixo `/app`; ele sai antes de qualquer outra regra.
const withoutLegacyPrefix = (value: string) => {
	let current = value;
	while (/^\/app(?=$|[/?#])/.test(current)) {
		const rest = current.slice('/app'.length);
		current = rest.startsWith('/') ? rest : `/${rest}`;
	}
	return current;
};

const pathnameOf = (value: string) => value.split(/[?#]/, 1)[0];

const isServerOwned = (value: string) => /^\/(?:api|_app|card_images)(?:\/|$)/.test(pathnameOf(value));

export const isFileRoute = (path: string) =>
	/^\/(?:collection\/export|decks\/[^/?#]+\.txt)(?:[?#]|$)/.test(path);

export function safeReturnTo(raw: string | null): string {
	const root = resolve('/');
	if (!raw) return root;

	let decoded: string;
	try {
		decoded = decodeURIComponent(raw);
	} catch {
		return root;
	}

	const isSuspicious = decoded.includes('//') || decoded.includes('\\') || hasControlCharacter(decoded);
	if (!raw.startsWith('/') || !decoded.startsWith('/') || isSuspicious || hasDotSegment(raw)) return root;

	const destination = withoutLegacyPrefix(raw);
	if (isServerOwned(destination) || isServerOwned(withoutLegacyPrefix(decoded))) return root;
	return destination;
}
