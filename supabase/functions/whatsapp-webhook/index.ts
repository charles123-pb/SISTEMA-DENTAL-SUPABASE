import { handleWebhook } from './handler.ts';

Deno.serve((request) => handleWebhook(request));
