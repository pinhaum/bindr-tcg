import { describe, expect, it } from 'vitest';
import type { ImportClassification, ImportRow } from '../api/types';
import {
	analyzedLines,
	failureSentence,
	groupRows,
	plural,
	rejectedSentence,
	removalWarning,
	removedSentence,
	unchangedSentence
} from './groups';

function row(line: number, classification: ImportClassification): ImportRow {
	return {
		line,
		classification,
		card_number: 'OP01-001',
		variant_code: 'tcgplayer:1',
		card_name: 'Carta',
		quantity_before: 1,
		quantity_after: 2,
		message: null
	};
}

describe('groupRows', () => {
	const shuffled = [
		row(1, 'unchanged'),
		row(2, 'creates'),
		row(3, 'rejected'),
		row(4, 'updates'),
		row(5, 'removes'),
		row(6, 'creates'),
		row(7, 'removes')
	];

	it('ordena os grupos de forma fixa, com título, frase de apoio e rótulo', () => {
		const groups = groupRows(shuffled);

		expect(groups.map((g) => g.classification)).toEqual([
			'removes',
			'creates',
			'updates',
			'rejected',
			'unchanged'
		]);
		expect(groups.map((g) => g.title)).toEqual([
			'Remove da coleção',
			'Passa a constar',
			'Altera a quantidade',
			'Não será importada',
			'Já está assim'
		]);
		expect(groups.map((g) => g.label)).toEqual([
			'Remove da coleção',
			'Cria',
			'Altera',
			'Recusada',
			'Sem alteração'
		]);
		expect(groups.map((g) => g.support)).toEqual([
			'Estas cartas você possui hoje e o arquivo traz zero: a posse desaparece na confirmação.',
			'Estas variantes ainda não estão na sua coleção e passarão a constar.',
			'A quantidade do arquivo substitui a que está na sua coleção hoje.',
			'Estas linhas do arquivo não serão aplicadas. O motivo de cada uma está abaixo.',
			'A quantidade do arquivo é a que você já tem: nada muda nestas linhas.'
		]);
	});

	it('mantém a ordem da resposta dentro do grupo', () => {
		const groups = groupRows(shuffled);

		expect(groups[0].rows.map((r) => r.line)).toEqual([5, 7]);
		expect(groups[1].rows.map((r) => r.line)).toEqual([2, 6]);
	});

	it('omite o grupo vazio', () => {
		const groups = groupRows([row(1, 'updates'), row(2, 'removes')]);

		expect(groups.map((g) => g.classification)).toEqual(['removes', 'updates']);
		expect(groupRows([])).toEqual([]);
	});
});

describe('plural', () => {
	it('usa o singular só para 1', () => {
		expect(plural(0, 'linha', 'linhas')).toBe('0 linhas');
		expect(plural(1, 'linha', 'linhas')).toBe('1 linha');
		expect(plural(2, 'linha', 'linhas')).toBe('2 linhas');
	});
});

describe('frases do import', () => {
	it('conta as linhas analisadas', () => {
		expect(analyzedLines(0)).toBe('0 linhas analisadas');
		expect(analyzedLines(1)).toBe('1 linha analisada');
		expect(analyzedLines(2)).toBe('2 linhas analisadas');
	});

	it('avisa da remoção', () => {
		expect(removalWarning(1)).toBe(
			'Atenção: 1 carta que você possui hoje sai da sua coleção se você confirmar.'
		);
		expect(removalWarning(2)).toBe(
			'Atenção: 2 cartas que você possui hoje saem da sua coleção se você confirmar.'
		);
	});

	it('resume as removidas', () => {
		expect(removedSentence(1)).toBe(
			'1 dessas atualizações removeu a carta da sua coleção: o arquivo trazia zero para uma variante que você possuía.'
		);
		expect(removedSentence(2)).toBe(
			'2 dessas atualizações removeram a carta da sua coleção: o arquivo trazia zero para 2 variantes que você possuía.'
		);
	});

	it('resume as inalteradas', () => {
		expect(unchangedSentence(1)).toBe(
			'1 linha do arquivo já estava assim na sua coleção: nada mudou nelas.'
		);
		expect(unchangedSentence(2)).toBe(
			'2 linhas do arquivo já estavam assim na sua coleção: nada mudou nelas.'
		);
	});

	it('resume as recusas', () => {
		expect(rejectedSentence(1)).toBe(
			'Confira estas linhas: 1 linha do arquivo não foi aplicada. Sua coleção não foi alterada por ela.'
		);
		expect(rejectedSentence(2)).toBe(
			'Confira estas linhas: 2 linhas do arquivo não foram aplicadas. Sua coleção não foi alterada por elas.'
		);
	});

	it('resume as falhas de gravação', () => {
		expect(failureSentence(1)).toBe(
			'Atenção: 1 linha não pôde ser gravada por um problema ao salvar. As demais entraram normalmente. Envie o arquivo de novo com essa linha para tentar outra vez.'
		);
		expect(failureSentence(2)).toBe(
			'Atenção: 2 linhas não puderam ser gravadas por um problema ao salvar. As demais entraram normalmente. Envie o arquivo de novo com essas linhas para tentar outra vez.'
		);
	});
});
