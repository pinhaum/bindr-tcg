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

export function safeReturnTo(raw: string | null): string {
	const base = resolve('/').replace(/\/$/, '');
	if (!raw) return base;

	let decoded: string;
	try {
		decoded = decodeURIComponent(raw);
	} catch {
		return base;
	}

	const isAppPath = (value: string) =>
		value === base || value.startsWith(`${base}/`) || value.startsWith(`${base}?`);
	const isInsideApp = isAppPath(raw) && isAppPath(decoded);
	const isSuspicious = decoded.includes('//') || decoded.includes('\\') || hasControlCharacter(decoded);
	return isInsideApp && !isSuspicious && !hasDotSegment(raw) ? raw : base;
}
