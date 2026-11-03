// The sponsor list of this deploy, which scripts/sponsors.mjs reads when it has no token or GitHub can't be read.
import type { APIRoute } from 'astro';
import sponsors from '../../data/sponsors.json';

export const GET: APIRoute = () => new Response(JSON.stringify(sponsors), { headers: { 'Content-Type': 'application/json' } });
