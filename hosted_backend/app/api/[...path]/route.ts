import { getBackground } from '../../../lib/background-context';
import { env } from 'cloudflare:workers';
import { getChatGPTUser } from '../../chatgpt-auth';
import { handle } from '../../../lib/api.mjs';
export const dynamic='force-dynamic';
async function route(req:Request) {
 return handle(req, env.DB!, await getChatGPTUser(), (env as any).ADMIN_OWNER_EMAIL, {waitUntil:getBackground(),telegramKey:(env as any).TELEGRAM_CONFIG_KEY});
}
export const GET=route, POST=route, PUT=route;
