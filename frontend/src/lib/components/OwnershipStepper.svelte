<script lang="ts">
	import { copies } from '../format';
	import type { OwnershipOp } from '../cards/ownership-queue.svelte';
	import QuantityStepper from './QuantityStepper.svelte';

	interface Props {
		name: string;
		variantCode: string;
		confirmed: number;
		send: (op: OwnershipOp) => Promise<number>;
		displayed?: number;
	}

	const NOTHING_TO_REMOVE = 'Você não tem cópias desta variante para remover.';

	let { name, variantCode, confirmed, send, displayed = $bindable() }: Props = $props();

	const quantityText = (quantity: number) => (quantity === 0 ? 'não tenho' : copies(quantity));
</script>

<QuantityStepper
	{confirmed}
	{send}
	bind:displayed
	decrementLabel="Remover uma cópia de {name} {variantCode}"
	incrementLabel="Adicionar uma cópia de {name} {variantCode}"
	refusedMessage={NOTHING_TO_REMOVE}
	{quantityText}
	settledText={(quantity) => `${quantityText(quantity)} ${name} ${variantCode}`}
/>
