import { requireSession } from '../../../../lib/navigation/require-session';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ parent, url }) => {
	await parent();
	requireSession(url);
};
