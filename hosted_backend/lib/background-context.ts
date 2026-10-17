import { AsyncLocalStorage } from 'node:async_hooks';
const background = new AsyncLocalStorage<(task: Promise<unknown>) => void>();
export const getBackground = () => background.getStore();
export function runWithBackground<T>(waitUntil: (task: Promise<unknown>) => void, run: () => T): T {
 return background.run(waitUntil, run);
}
