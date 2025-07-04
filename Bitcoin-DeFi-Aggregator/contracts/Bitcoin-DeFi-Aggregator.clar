
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
