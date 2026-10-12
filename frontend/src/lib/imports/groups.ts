import type { ImportClassification, ImportRow } from '../api/types';

export type ImportGroup = {
	classification: ImportClassification;
	title: string;
	support: string;
	label: string;
	rows: ImportRow[];
};

type GroupCopy = Pick<ImportGroup, 'classification' | 'title' | 'support' | 'label'>;

const GROUPS: GroupCopy[] = [
	{
		classification: 'removes',
		title: 'Remove da coleção',
		support: 'Estas cartas você possui hoje e o arquivo traz zero: a posse desaparece na confirmação.',
		label: 'Remove da coleção'
	},
	{
		classification: 'creates',
		title: 'Passa a constar',
		support: 'Estas variantes ainda não estão na sua coleção e passarão a constar.',
		label: 'Cria'
	},
	{
		classification: 'updates',
		title: 'Altera a quantidade',
		support: 'A quantidade do arquivo substitui a que está na sua coleção hoje.',
		label: 'Altera'
	},
	{
		classification: 'rejected',
		title: 'Não será importada',
		support: 'Estas linhas do arquivo não serão aplicadas. O motivo de cada uma está abaixo.',
		label: 'Recusada'
	},
	{
		classification: 'unchanged',
		title: 'Já está assim',
		support: 'A quantidade do arquivo é a que você já tem: nada muda nestas linhas.',
		label: 'Sem alteração'
	}
];

export function groupRows(rows: ImportRow[]): ImportGroup[] {
	return GROUPS.map((copy) => ({
		...copy,
		rows: rows.filter((row) => row.classification === copy.classification)
	})).filter((group) => group.rows.length > 0);
}

export function plural(n: number, one: string, many: string): string {
	return `${n} ${n === 1 ? one : many}`;
}

export function analyzedLines(n: number): string {
	return plural(n, 'linha analisada', 'linhas analisadas');
}

export function removalWarning(n: number): string {
	return n === 1
		? 'Atenção: 1 carta que você possui hoje sai da sua coleção se você confirmar.'
		: `Atenção: ${n} cartas que você possui hoje saem da sua coleção se você confirmar.`;
}

export function removedSentence(n: number): string {
	return n === 1
		? '1 dessas atualizações removeu a carta da sua coleção: o arquivo trazia zero para uma variante que você possuía.'
		: `${n} dessas atualizações removeram a carta da sua coleção: o arquivo trazia zero para ${n} variantes que você possuía.`;
}

export function unchangedSentence(n: number): string {
	return n === 1
		? '1 linha do arquivo já estava assim na sua coleção: nada mudou nelas.'
		: `${n} linhas do arquivo já estavam assim na sua coleção: nada mudou nelas.`;
}

export function rejectedSentence(n: number): string {
	return n === 1
		? 'Confira estas linhas: 1 linha do arquivo não foi aplicada. Sua coleção não foi alterada por ela.'
		: `Confira estas linhas: ${n} linhas do arquivo não foram aplicadas. Sua coleção não foi alterada por elas.`;
}

export function failureSentence(n: number): string {
	return n === 1
		? 'Atenção: 1 linha não pôde ser gravada por um problema ao salvar. As demais entraram normalmente. Envie o arquivo de novo com essa linha para tentar outra vez.'
		: `Atenção: ${n} linhas não puderam ser gravadas por um problema ao salvar. As demais entraram normalmente. Envie o arquivo de novo com essas linhas para tentar outra vez.`;
}
