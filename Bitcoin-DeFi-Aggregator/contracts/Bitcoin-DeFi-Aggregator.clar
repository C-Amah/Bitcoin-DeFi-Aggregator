
;; title: Bitcoin-DeFi-Aggregator
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-protocol-not-whitelisted (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-no-liquidity (err u104))
(define-constant err-slippage-too-high (err u105))
(define-constant err-deadline-passed (err u106))
(define-constant err-protocol-already-whitelisted (err u107))
(define-constant err-invalid-risk-score (err u108))
(define-constant err-protocol-disabled (err u109))
(define-constant err-batch-failed (err u110))
(define-constant err-route-not-found (err u111))

;; Protocol structure
(define-map protocols
  { protocol-id: uint }
  {
    name: (string-ascii 64),
    address: principal,
    enabled: bool,
    risk-score: uint,  ;; Risk score from 1-100, where 1 is lowest risk and 100 is highest risk
    current-yield: uint,  ;; APY in basis points (e.g., 500 = 5%)
    liquidity: uint,  ;; Total liquidity in the protocol (in microSTX)
    volume-24h: uint  ;; 24-hour trading volume (in microSTX)
  }
)

;; Track supported tokens
(define-map supported-tokens
  { token-id: uint }
  {
    name: (string-ascii 64),
    symbol: (string-ascii 10),
    decimals: uint,
    token-contract: principal
  }
)

;; Mapping to track which protocols support which tokens
(define-map protocol-token-support
  { protocol-id: uint, token-id: uint }
  { supported: bool }
)

;; User positions across protocols
(define-map user-positions
  { user: principal, protocol-id: uint, token-id: uint }
  { amount: uint }
)

;; Track total user deposits by token
(define-map user-deposits
  { user: principal, token-id: uint }
  { total-amount: uint }
)

;; Yield strategy types
(define-map yield-strategies
  { strategy-id: uint }
  {
    name: (string-ascii 64),
    description: (string-ascii 256),
    risk-level: uint,  ;; 1-5, where 1 is lowest risk and 5 is highest risk
    enabled: bool,
    target-yield: uint, ;; Target APY in basis points
    min-deposit: uint,  ;; Minimum deposit required
    max-deposit: uint,  ;; Maximum deposit allowed
    rebalance-frequency: uint  ;; How often the strategy rebalances (in blocks)
  }
)

;; User strategy allocations
(define-map user-strategies
  { user: principal, strategy-id: uint }
  { amount: uint }
)

;; Track protocol statistics for historical data
(define-map protocol-stats-daily
  { protocol-id: uint, day: uint }
  {
    avg-yield: uint,
    total-liquidity: uint,
    txn-count: uint,
    unique-users: uint
  }
)

;; Route cache to optimize gas usage
(define-map route-cache
  { from-token: uint, to-token: uint, amount: uint }
  {
    best-route: (list 10 uint),  ;; List of protocol IDs to route through
    expected-output: uint,
    calculated-at-block: uint
  }
)

;; Protocol fee settings
(define-data-var protocol-fee-bps uint u10)  ;; 0.1% default fee
(define-data-var fee-recipient principal contract-owner)

;; Protocol counters
(define-data-var next-protocol-id uint u1)
(define-data-var next-token-id uint u1)
(define-data-var next-strategy-id uint u1)

