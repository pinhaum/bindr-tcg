export type ApiEnvelope<T> = { data: T; meta?: Record<string, unknown> };

export type ApiErrorBody = {
	error: { code: string; message: string; fields?: unknown };
};

export type SessionUser = { email: string };

export type SessionPayload = { user: SessionUser | null; csrf_token: string };

export type CatalogVariant = {
	variant_code: string;
	rarity: string | null;
	art_kind: string;
	set: { code: string; name: string };
	illustrator: string | null;
	image_url: string | null;
	in_source: boolean;
	owned_quantity: number | null;
	wishlist_target: number | null;
	price: { amount: string; currency: string; observed_at: string } | null;
};

export type CatalogCard = {
	card_number: string;
	name: string;
	card_type: string;
	colors: string[];
	cost: number | null;
	life: number | null;
	power: number | null;
	counter: number | null;
	block_icon: number | null;
	attributes: string[];
	traits: string[];
	effect_text: string | null;
	trigger_text: string | null;
	set: { code: string; name: string };
	variants: CatalogVariant[];
};

export type ActiveFilters = Partial<{
	q: string;
	colors: string[];
	card_types: string[];
	sets: string[];
	rarities: string[];
	attributes: string[];
	traits: string[];
	cost_min: number;
	cost_max: number;
	power_min: number;
	power_max: number;
	counter_min: number;
	counter_max: number;
	owned: 'owned' | 'missing';
	sort: string;
	dir: 'asc' | 'desc';
}>;

export type CatalogMeta = {
	page: number;
	per_page: number;
	total_count: number;
	total_pages: number;
	active_filters: ActiveFilters;
};

export type CatalogPage = { data: CatalogCard[]; meta: CatalogMeta };

export type FilterOptions = {
	colors: string[];
	card_types: string[];
	rarities: string[];
	sets: { code: string; name: string }[];
};

export type DetailVariant = CatalogVariant;

export type CardDetailPayload = Omit<CatalogCard, 'variants'> & {
	featured_variant_code: string | null;
	variants: DetailVariant[];
};

export type OwnershipResult = { variant_code: string; owned_quantity: number };

export type WishlistResult = { variant_code: string; wishlist_target: number };
