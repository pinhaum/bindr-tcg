<script lang="ts">
	interface Props {
		name: string;
		cardNumber: string;
		imageUrl: string | null;
		alt: string;
		transitionName?: string;
	}

	let { name, cardNumber, imageUrl, alt, transitionName }: Props = $props();

	let failedUrl = $state<string | null>(null);
	const showImage = $derived(imageUrl !== null && imageUrl !== failedUrl);
</script>

<div class="art" style:view-transition-name={transitionName}>
	<div class="placeholder" aria-hidden="true">
		<span class="placeholder-name">{name}</span>
		<span class="placeholder-number">{cardNumber}</span>
	</div>

	{#if showImage}
		<img class="image" src={imageUrl} {alt} onerror={() => (failedUrl = imageUrl)} />
	{/if}
</div>

<style>
	.art {
		position: relative;
		aspect-ratio: 5 / 7;
		overflow: hidden;
		border-radius: var(--radius-md);
		background: var(--surface-sunken);
	}

	.image,
	.placeholder {
		position: absolute;
		inset: 0;
		inline-size: 100%;
		block-size: 100%;
		max-inline-size: 100%;
	}

	.image {
		object-fit: cover;
	}

	.placeholder {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: var(--space-1);
		padding: var(--space-2);
		box-sizing: border-box;
		text-align: center;
		font-size: var(--caption-size);
		line-height: var(--caption-line-height);
		background-color: var(--surface-sunken);
	}

	.placeholder-number {
		font-variant-numeric: tabular-nums;
		color: var(--ink-muted);
	}

	.placeholder-name {
		font-weight: var(--body-strong-weight);
		overflow-wrap: anywhere;
	}
</style>
