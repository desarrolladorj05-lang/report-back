export interface LiquidationDashboardResponse {
  period: { dateFrom: string; dateTo: string; days: number };
  comparison: {
    period: { dateFrom: string; dateTo: string };
    totalToRender: number;
    totalCollected: number;
    difference: number;
    liquidationCount: number;
    pendingCount: number;
    totalToRenderChange: number;
    totalCollectedChange: number;
    differenceChange: number;
    liquidationCountChange: number;
    pendingCountChange: number;
  };
  totals: {
    totalToRender: number;
    totalCollected: number;
    difference: number;
    deposited: number;
    collected: number;
    liquidationCount: number;
    compliantCount: number;
    pendingCount: number;
    collectionRate: number;
  };
  daily: Array<{
    date: string;
    totalToRender: number;
    totalCollected: number;
    difference: number;
    liquidationCount: number;
  }>;
  paymentMethods: Array<{
    name: string;
    collected: number;
    deposited: number;
    difference: number;
    percentage: number;
  }>;
  locations: Array<{
    localNumber: number;
    name: string;
    color: string;
    totalToRender: number;
    totalCollected: number;
    difference: number;
    liquidationCount: number;
    compliantCount: number;
    pendingCount: number;
    status: "COMPLIANT" | "REVIEW";
  }>;
  rankings: {
    locations: LiquidationRankingItem[];
    responsibles: LiquidationRankingItem[];
  };
}

export interface LiquidationRankingItem {
  key: string;
  label: string;
  detail?: string;
  count: number;
  amount: number;
}

export interface LiquidationCashRegister {
  id: string;
  date: string;
  localNumber: number;
  location: string;
  cashRegisterCode: number;
  responsible: string;
  totalToRender: number;
  totalCollected: number;
  difference: number;
  status: "COMPLIANT" | "REVIEW";
}
