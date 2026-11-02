// Mesma lista do STRO-08, menos /_app (no dev o Vite não serve build).
// `collection_items` e os prefixos antigos entram para que um POST velho chegue
// ao Rails e receba o 404 (STRO-15) também em desenvolvimento.
export const RAILS_PATH_PATTERN =
	'^/(api|card_images|up|app|catalog|cards|session|registration|progress|wishlist' +
	'|collection|collection_items|decks|icon\\.png|icon\\.svg|robots\\.txt|[0-9]{3}[^/]*\\.html)(/|\\?|$)';
