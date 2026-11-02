// Live numbers for the home page: PowerShell Gallery downloads and GitHub stars, with the committed fallback
// in src/data/stats.json when the build can't reach either service.
import fallback from '../data/stats.json' with { type: 'json' };

async function fetchText(url) {
	const response = await fetch(url, { signal: AbortSignal.timeout(5000), headers: { 'User-Agent': 'maester.dev build' } });
	if (!response.ok) throw new Error(`${url}: ${response.status}`);
	return response.text();
}

async function downloads() {
	try {
		const xml = await fetchText("https://www.powershellgallery.com/api/v2/FindPackagesById()?id='Maester'&$top=1&$orderby=Version%20desc");
		const n = Number(xml.match(/<d:DownloadCount[^>]*>(\d+)</)?.[1]);
		return n > fallback.downloads ? n : fallback.downloads;
	} catch {
		return fallback.downloads;
	}
}

async function stars() {
	try {
		const json = JSON.parse(await fetchText('https://api.github.com/repos/maester365/maester'));
		return json.stargazers_count > 0 ? json.stargazers_count : fallback.stars;
	} catch {
		return fallback.stars;
	}
}

let cached;
export function getStats() {
	cached ??= Promise.all([downloads(), stars()]).then(([d, s]) => ({ downloads: d, stars: s }));
	return cached;
}

// 624960 -> "625K+", 1171 -> "1.2K"
export function compact(n, plus = false) {
	if (n >= 1000) {
		const k = n / 1000;
		return `${k >= 100 ? Math.round(k) : k.toFixed(1).replace(/\.0$/, '')}K${plus ? '+' : ''}`;
	}
	return String(n);
}
