export type ThemePreference = 'system' | 'light' | 'dark';
export type EffectiveTheme = 'light' | 'dark';

const STORAGE_KEY = 'bindr-theme';
const DARK_QUERY = '(prefers-color-scheme: dark)';

const isPreference = (value: unknown): value is ThemePreference =>
	value === 'system' || value === 'light' || value === 'dark';

const readPreference = (): ThemePreference => {
	const attr = document.documentElement.getAttribute('data-theme-preference');
	return isPreference(attr) ? attr : 'system';
};

export const theme = $state<{ preference: ThemePreference }>({ preference: readPreference() });

const darkQuery = matchMedia(DARK_QUERY);
let listening = false;

const effective = (): EffectiveTheme =>
	theme.preference === 'system' ? (darkQuery.matches ? 'dark' : 'light') : theme.preference;

function apply() {
	const root = document.documentElement;
	root.setAttribute('data-theme', effective());
	root.setAttribute('data-theme-preference', theme.preference);
}

function syncListener() {
	const wanted = theme.preference === 'system';
	if (wanted === listening) return;
	listening = wanted;
	if (wanted) darkQuery.addEventListener('change', apply);
	else darkQuery.removeEventListener('change', apply);
}

export function setPreference(preference: ThemePreference) {
	theme.preference = preference;
	try {
		localStorage.setItem(STORAGE_KEY, preference);
	} catch {
		// armazenamento indisponível: a troca vale só nesta sessão
	}
	apply();
	syncListener();
}

syncListener();
