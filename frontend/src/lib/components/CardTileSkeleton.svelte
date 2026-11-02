<li class="tile" aria-hidden="true">
	<div class="art"></div>
	<span class="line name"></span>
	<span class="line number-line"></span>
</li>

<style>
	.tile {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
		max-inline-size: 100%;
		padding: var(--space-3);
		background-color: var(--surface-raised);
		border: 1px solid var(--border);
		border-radius: var(--radius-md);
		list-style: none;
		animation: pulse var(--duration-slow) ease-in-out infinite alternate;
	}

	.art {
		aspect-ratio: 5 / 7;
		border-radius: var(--radius-md);
		background: var(--surface-sunken);
	}

	.line {
		display: block;
		border-radius: var(--radius-sm);
		background: var(--surface-sunken);
	}

	.name {
		block-size: var(--body-strong-line-height);
		inline-size: 80%;
	}

	.number-line {
		block-size: var(--caption-line-height);
		inline-size: 50%;
	}

	@keyframes pulse {
		from {
			opacity: 1;
		}

		to {
			opacity: 0.5;
		}
	}
</style>
