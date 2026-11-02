export function isPlainClick(event: MouseEvent): boolean {
	return event.button === 0 && !(event.ctrlKey || event.metaKey || event.shiftKey || event.altKey);
}
