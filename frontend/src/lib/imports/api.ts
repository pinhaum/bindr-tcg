export const IMPORTS_PATH = '/api/collection/imports';

export const IMPORT_TIMEOUT_MS = 60000;

export const importPath = (token: string): string => `${IMPORTS_PATH}/${encodeURIComponent(token)}`;

export const confirmPath = (token: string): string => `${importPath(token)}/confirm`;
