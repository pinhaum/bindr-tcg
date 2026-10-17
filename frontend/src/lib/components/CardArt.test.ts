import { fireEvent, render } from '@testing-library/svelte';
import { describe, expect, it } from 'vitest';
import CardArt from './CardArt.svelte';

const base = { name: 'Monkey.D.Luffy', cardNumber: 'OP01-003', alt: 'Monkey.D.Luffy tcgplayer:1' };

describe('CardArt', () => {
	it('mostra a imagem com o alt recebido e o placeholder atrás', () => {
		const { container, getByAltText } = render(CardArt, { ...base, imageUrl: '/card_images/x' });

		expect(getByAltText('Monkey.D.Luffy tcgplayer:1').getAttribute('src')).toBe('/card_images/x');
		const placeholder = container.querySelector('.placeholder');
		expect(placeholder?.textContent).toContain('Monkey.D.Luffy');
		expect(placeholder?.textContent).toContain('OP01-003');
	});

	it('sem image_url não renderiza <img> e mantém o placeholder', () => {
		const { container } = render(CardArt, { ...base, imageUrl: null });

		expect(container.querySelector('img')).toBeNull();
		expect(container.querySelector('.placeholder')).not.toBeNull();
	});

	it('esconde a imagem quando ela falha', async () => {
		const { container } = render(CardArt, { ...base, imageUrl: '/card_images/x' });

		await fireEvent.error(container.querySelector('img') as HTMLImageElement);

		expect(container.querySelector('img')).toBeNull();
		expect(container.querySelector('.placeholder')).not.toBeNull();
	});

	it('usa a mesma classe de quadro com imagem, sem imagem e com erro', async () => {
		const withImage = render(CardArt, { ...base, imageUrl: '/card_images/x' });
		const without = render(CardArt, { ...base, imageUrl: null });
		const failed = render(CardArt, { ...base, imageUrl: '/card_images/y' });
		await fireEvent.error(failed.container.querySelector('img') as HTMLImageElement);

		for (const { container } of [withImage, without, failed]) {
			expect(container.querySelector('.art')).not.toBeNull();
		}
	});

	it('aplica view-transition-name só quando transitionName é recebido', () => {
		const named = render(CardArt, { ...base, imageUrl: null, transitionName: 'card-OP01-003' });
		const plain = render(CardArt, { ...base, imageUrl: null });

		expect(named.container.querySelector('.art')?.getAttribute('style')).toContain(
			'view-transition-name: card-OP01-003'
		);
		expect(plain.container.querySelector('.art')?.hasAttribute('style')).toBe(false);
	});
});
