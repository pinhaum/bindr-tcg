import type { DeckEntryLine, DeckPayload, DeckStatus } from '../api/types';

const STATUS_LABELS: Record<DeckStatus, string> = {
	valid: 'válido',
	incomplete: 'incompleto',
	invalid: 'inválido',
};

const GROUP_LABELS: Record<string, string> = {
	character: 'Personagens',
	event: 'Eventos',
	stage: 'Locais',
};

export const statusLabel = (status: DeckStatus): string => STATUS_LABELS[status];

export const groupLabel = (cardType: string): string =>
	GROUP_LABELS[cardType] ?? cardType.charAt(0).toUpperCase() + cardType.slice(1);

export type EntryGroup = { cardType: string; entries: DeckEntryLine[] };

export function groupEntries(entries: DeckEntryLine[]): EntryGroup[] {
	const groups: EntryGroup[] = [];
	for (const entry of entries) {
		const last = groups.at(-1);
		if (last?.cardType === entry.card_type) last.entries.push(entry);
		else groups.push({ cardType: entry.card_type, entries: [entry] });
	}
	return groups;
}

export function missingSentence(deck: Pick<DeckPayload, 'leader' | 'entries' | 'missing_total'>): string {
	if (deck.leader === null && deck.entries.length === 0) return 'Este deck ainda não tem cartas';
	if (deck.missing_total === 0) return 'Você tem todas as cartas deste deck';
	if (deck.missing_total === 1) return 'Falta 1 cópia para montar este deck';
	return `Faltam ${deck.missing_total} cópias para montar este deck`;
}
