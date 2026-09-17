export function isLiquidationDifferenceBalanced(difference: number) {
  return Math.round((difference + Number.EPSILON) * 100) === 0;
}
