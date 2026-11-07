import assets from './admin-assets.generated.mjs';
import { adminFetch } from './routes.mjs';

export default { fetch: (request, env, ctx) => adminFetch(request, env, ctx, assets) };
