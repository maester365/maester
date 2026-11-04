// The filters of the test catalog, shared by the nav (CatalogNav.astro) and the list on the page (CatalogList.astro).
// The URL is the state: each filter is a query parameter with comma-separated values, so a filtered view can be
// shared and survives a reload. A change is announced with a `mt-catalog` event on window.

export const FILTERS = ['q', 'severity', 'area', 'cost', 'impact', 'source', 'channel', 'product', 'feature', 'suite', 'mitre', 'pillar', 'author', 'group'] as const;
export type Filter = (typeof FILTERS)[number];
export type State = Record<Filter, string[]>;

export function readState(): State {
	const params = new URLSearchParams(location.search);
	const state = {} as State;
	for (const name of FILTERS) {
		const value = params.get(name) ?? '';
		// eslint-disable-next-line security/detect-object-injection -- name is one of FILTERS
		state[name] = name === 'q' ? (value ? [value] : []) : value.split(',').filter(Boolean);
	}
	return state;
}

export function writeState(state: State) {
	const params = new URLSearchParams();
	// eslint-disable-next-line security/detect-object-injection -- name is one of FILTERS
	for (const name of FILTERS) if (state[name].length) params.set(name, state[name].join(','));
	const query = params.toString().replace(/%2C/g, ',');
	history.replaceState(null, '', query ? `?${query}` : location.pathname);
	window.dispatchEvent(new CustomEvent('mt-catalog', { detail: state }));
}

export function update(change: Partial<State>) {
	writeState({ ...readState(), ...change });
}

export function toggle(name: Filter, value: string, on: boolean) {
	const state = readState();
	// eslint-disable-next-line security/detect-object-injection -- name is one of FILTERS
	const set = new Set(state[name]);
	if (on) set.add(value);
	else set.delete(value);
	writeState({ ...state, [name]: [...set] });
}

export function onState(listener: (state: State) => void) {
	window.addEventListener('mt-catalog', (e) => {
		listener((e as CustomEvent<State>).detail);
	});
	listener(readState());
}

// Filters that narrow the checks (all but how they are grouped).
// eslint-disable-next-line security/detect-object-injection -- name is one of FILTERS
export const isFiltered = (state: State) => FILTERS.some((name) => name !== 'group' && state[name].length > 0);
