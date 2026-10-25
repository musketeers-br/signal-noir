import '@testing-library/jest-dom/vitest';
import { cleanup } from '@testing-library/svelte';
import { afterEach } from 'vitest';

// jsdom has no layout: stub what the console calls.
if (!Element.prototype.scrollIntoView) Element.prototype.scrollIntoView = function () {};
if (!window.matchMedia) {
	window.matchMedia = ((q: string) => ({ matches: false, media: q, onchange: null, addListener() {}, removeListener() {}, addEventListener() {}, removeEventListener() {}, dispatchEvent: () => false })) as typeof window.matchMedia;
}
// <dialog> modal behavior, if jsdom lacks it
const proto = HTMLDialogElement.prototype as HTMLDialogElement & { showModal?: () => void };
if (typeof proto.showModal !== 'function') {
	proto.showModal = function (this: HTMLDialogElement) {
		this.setAttribute('open', '');
	};
	proto.close = function (this: HTMLDialogElement) {
		this.removeAttribute('open');
		this.dispatchEvent(new Event('close'));
	};
}

afterEach(() => {
	cleanup();
	localStorage.clear();
	location.hash = '';
});
