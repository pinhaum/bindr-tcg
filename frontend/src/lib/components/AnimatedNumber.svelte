<script lang="ts">
	import { untrack } from 'svelte';
	import { Tween } from 'svelte/motion';
	import { duration, easeStandard } from '../motion';

	type Props = {
		value: number;
		format: (n: number) => string;
		finalText: string;
	};

	let { value, format, finalText }: Props = $props();

	const tween = new Tween(untrack(() => (duration(320) === 0 ? value : 0)));

	$effect(() => {
		const target = value;
		const ms = untrack(() => duration(320));
		tween.set(target, { duration: ms, easing: easeStandard });
	});
</script>

<span class="root">
	<span class="number" aria-hidden="true">
		{tween.current === value ? finalText : format(Math.round(tween.current))}
	</span>
	<span class="reserve" aria-hidden="true">{finalText}</span>
	<span class="visually-hidden">{finalText}</span>
</span>

<style>
	.root {
		display: inline-grid;
		font-variant-numeric: tabular-nums;
	}

	.number,
	.reserve {
		grid-area: 1 / 1;
	}

	.reserve {
		visibility: hidden;
	}
</style>
