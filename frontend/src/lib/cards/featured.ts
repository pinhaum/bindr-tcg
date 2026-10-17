import type { DetailVariant } from '../api/types';

export function pickFeatured(
	variants: DetailVariant[],
	variantParam: string | null | undefined
): DetailVariant | null {
	return (
		variants.find((v) => v.variant_code === variantParam) ??
		variants.find((v) => v.in_source) ??
		variants[0] ??
		null
	);
}
