export interface InventoryVersionCutoverConfig {
  fullV2From: string;
  outputsV2From: string;
}

const INVENTORY_V2_CUTOVER_DATE_BY_DATABASE = {
  tenant_santa_isabel: {
    fullV2From: "2026-10-23",
    outputsV2From: "2026-10-24",
  },
} as const satisfies Readonly<Record<string, InventoryVersionCutoverConfig>>;

export const getInventoryV2CutoverConfig = (
  databaseName: string | undefined,
): InventoryVersionCutoverConfig | null => {
  if (!databaseName) return null;
  const configs: Readonly<Record<string, InventoryVersionCutoverConfig>> =
    INVENTORY_V2_CUTOVER_DATE_BY_DATABASE;
  return configs[databaseName] ?? null;
};
