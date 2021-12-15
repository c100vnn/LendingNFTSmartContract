export interface Contract {
  name: string
  address: string
}

export interface Contracts {
  token?: Contract
  reserve?: Contract
  staking?: Contract
  rewardPool?: Contract
}