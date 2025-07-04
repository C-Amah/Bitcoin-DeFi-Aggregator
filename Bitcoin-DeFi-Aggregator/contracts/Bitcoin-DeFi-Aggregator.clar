
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

;; Contract status
(define-data-var contract-paused bool false)

;; Governance variables
(define-data-var governance-token principal .btc-defi-gov-token)
(define-data-var proposal-threshold uint u100000000) ;; Minimum tokens needed to submit proposal

(define-public (add-protocol (name (string-ascii 64)) (protocol-address principal) (risk-score uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (< risk-score u101) err-invalid-risk-score)
    
    (let ((protocol-id (var-get next-protocol-id)))
      (map-set protocols
        { protocol-id: protocol-id }
        {
          name: name,
          address: protocol-address,
          enabled: true,
          risk-score: risk-score,
          current-yield: u0,
          liquidity: u0,
          volume-24h: u0
        }
      )
      (var-set next-protocol-id (+ protocol-id u1))
      (ok protocol-id)
    )
  )
)

(define-public (toggle-protocol (protocol-id uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    (let ((protocol (unwrap! (map-get? protocols { protocol-id: protocol-id }) err-protocol-not-whitelisted)))
      (map-set protocols
        { protocol-id: protocol-id }
        (merge protocol { enabled: (not (get enabled protocol)) })
      )
      (ok (not (get enabled protocol)))
    )
  )
)

(define-public (add-token (name (string-ascii 64)) (symbol (string-ascii 10)) (decimals uint) (token-contract principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    (let ((token-id (var-get next-token-id)))
      (map-set supported-tokens
        { token-id: token-id }
        {
          name: name,
          symbol: symbol,
          decimals: decimals,
          token-contract: token-contract
        }
      )
      (var-set next-token-id (+ token-id u1))
      (ok token-id)
    )
  )
)

(define-public (set-protocol-token-support (protocol-id uint) (token-id uint) (is-supported bool))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-some (map-get? protocols { protocol-id: protocol-id })) err-protocol-not-whitelisted)
    (asserts! (is-some (map-get? supported-tokens { token-id: token-id })) (err u112))
    
    (map-set protocol-token-support
      { protocol-id: protocol-id, token-id: token-id }
      { supported: is-supported }
    )
    (ok is-supported)
  )
)

(define-public (set-protocol-fee (new-fee-bps uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-fee-bps u10000) (err u113))  ;; Ensure fee is not greater than 100%
    
    (var-set protocol-fee-bps new-fee-bps)
    (ok new-fee-bps)
  )
)

(define-public (set-fee-recipient (new-recipient principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set fee-recipient new-recipient)
    (ok new-recipient)
  )
)

(define-public (add-yield-strategy 
  (name (string-ascii 64)) 
  (description (string-ascii 256)) 
  (risk-level uint) 
  (target-yield uint)
  (min-deposit uint)
  (max-deposit uint)
  (rebalance-frequency uint)
)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (and (>= risk-level u1) (<= risk-level u5)) (err u114))
    
    (let ((strategy-id (var-get next-strategy-id)))
      (map-set yield-strategies
        { strategy-id: strategy-id }
        {
          name: name,
          description: description,
          risk-level: risk-level,
          enabled: true,
          target-yield: target-yield,
          min-deposit: min-deposit,
          max-deposit: max-deposit,
          rebalance-frequency: rebalance-frequency
        }
      )
      (var-set next-strategy-id (+ strategy-id u1))
      (ok strategy-id)
    )
  )
)

(define-public (toggle-strategy (strategy-id uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    (let ((strategy (unwrap! (map-get? yield-strategies { strategy-id: strategy-id }) (err u115))))
      (map-set yield-strategies
        { strategy-id: strategy-id }
        (merge strategy { enabled: (not (get enabled strategy)) })
      )
      (ok (not (get enabled strategy)))
    )
  )
)

(define-public (update-protocol-yield (protocol-id uint) (new-yield uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-some (map-get? protocols { protocol-id: protocol-id })) err-protocol-not-whitelisted)
    
    (let ((protocol (unwrap-panic (map-get? protocols { protocol-id: protocol-id }))))
      (map-set protocols
        { protocol-id: protocol-id }
        (merge protocol { current-yield: new-yield })
      )
      (ok new-yield)
    )
  )
)

(define-public (emergency-pause)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-paused true)
    (ok true)
  )
)

(define-public (emergency-unpause)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-paused false)
    (ok true)
  )
)

;; Simulate result from a protocol
(define-private (simulate-swap (from-token uint) (to-token uint) (amount uint) (protocol-id uint))
  (let (
    (protocol (unwrap-panic (map-get? protocols { protocol-id: protocol-id })))
    (liquidity (get liquidity protocol))
    (fee-rate (var-get protocol-fee-bps))
  )
    (if (< liquidity (* amount u10))
      ;; High slippage if liquidity is low
      (/ (* amount u95) u100)
      ;; Lower slippage for high liquidity
      (/ (* amount (- u10000 fee-rate)) u10000)
    )
  )
)

;; Find a protocol that supports the given token pair
(define-private (find-protocol-for-pair (from-token uint) (to-token uint))
  (if (is-some (map-get? protocols { protocol-id: u1 }))
    (some u1)
    none
  )
)

;; Execute route across protocols
(define-private (execute-route (from-token uint) (to-token uint) (amount uint) (route (list 10 uint)))
  (let (
    (protocol-id (unwrap! (element-at route u0) err-route-not-found))
    (protocol (unwrap! (map-get? protocols { protocol-id: protocol-id }) err-protocol-not-whitelisted))
  )
    (asserts! (get enabled protocol) err-protocol-disabled)
    (ok (simulate-swap from-token to-token amount protocol-id))
  )
)

;; Update statistics after a swap
(define-private (update-swap-stats (from-token uint) (to-token uint) (input-amount uint) (output-amount uint))
  (let (
    (protocol-id (unwrap-panic (element-at (get best-route (unwrap-panic (map-get? route-cache 
      { from-token: from-token, to-token: to-token, amount: input-amount }))) u0)))
    (protocol (unwrap-panic (map-get? protocols { protocol-id: protocol-id })))
    (current-volume (get volume-24h protocol))
  )
    (map-set protocols
      { protocol-id: protocol-id }
      (merge protocol { volume-24h: (+ current-volume input-amount) })
    )
    true
  )
)

;; Rebalance a strategy (admin function)
(define-public (rebalance-strategy (strategy-id uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (var-get contract-paused)) (err u116))
    
    (let ((strategy (unwrap! (map-get? yield-strategies { strategy-id: strategy-id }) (err u115))))
      ;; In a real implementation, this would:
      ;; 1. Analyze current allocations across protocols
      ;; 2. Calculate optimal allocations based on current yields and risk parameters
      ;; 3. Execute transactions to rebalance funds
      
      ;; For this example, we'll just return success
      (ok true)
    )
  )
)


;; Data structure for batch swap operations
(define-data-var batch-id uint u0)

(define-map batch-operations
  { batch-id: uint, operation-id: uint }
  {
    from-token: uint,
    to-token: uint,
    amount: uint,
    min-output: uint
  }
)

;; Create a new batch
(define-public (create-batch)
  (let ((current-batch-id (var-get batch-id)))
    (var-set batch-id (+ current-batch-id u1))
    (ok current-batch-id)
  )
)
