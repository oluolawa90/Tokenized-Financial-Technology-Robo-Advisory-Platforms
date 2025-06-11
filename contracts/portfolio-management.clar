;; Portfolio Management Contract
;; Manages investment portfolios for clients

(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_PORTFOLIO_EXISTS (err u201))
(define-constant ERR_PORTFOLIO_NOT_FOUND (err u202))
(define-constant ERR_INVALID_ALLOCATION (err u203))
(define-constant ERR_FIRM_NOT_VERIFIED (err u204))

;; Asset types
(define-constant ASSET_STOCKS u1)
(define-constant ASSET_BONDS u2)
(define-constant ASSET_COMMODITIES u3)
(define-constant ASSET_CRYPTO u4)
(define-constant ASSET_CASH u5)

;; Data structures
(define-map portfolios
  { portfolio-id: uint }
  {
    client: principal,
    advisor-firm-id: uint,
    creation-date: uint,
    total-value: uint,
    risk-score: uint,
    status: uint  ;; 0=inactive, 1=active, 2=suspended
  }
)

(define-map portfolio-allocations
  { portfolio-id: uint, asset-type: uint }
  {
    target-percentage: uint,  ;; Basis points (10000 = 100%)
    current-percentage: uint,
    current-value: uint
  }
)

(define-map client-portfolios
  { client: principal }
  { portfolio-id: uint }
)

(define-data-var next-portfolio-id uint u1)

;; Create a new portfolio
(define-public (create-portfolio
  (advisor-firm-id uint)
  (risk-score uint)
  (stock-allocation uint)
  (bond-allocation uint)
  (commodity-allocation uint)
  (crypto-allocation uint)
  (cash-allocation uint)
)
  (let ((portfolio-id (var-get next-portfolio-id))
        (total-allocation (+ stock-allocation (+ bond-allocation (+ commodity-allocation (+ crypto-allocation cash-allocation))))))

    ;; Validate inputs
    (asserts! (is-none (map-get? client-portfolios { client: tx-sender })) ERR_PORTFOLIO_EXISTS)
    (asserts! (is-eq total-allocation u10000) ERR_INVALID_ALLOCATION) ;; Must equal 100%
    (asserts! (<= risk-score u100) ERR_INVALID_ALLOCATION)

    ;; Check if advisor firm is verified (would need to call verification contract)
    ;; For simplicity, assuming verification check passes

    ;; Create portfolio
    (map-set portfolios
      { portfolio-id: portfolio-id }
      {
        client: tx-sender,
        advisor-firm-id: advisor-firm-id,
        creation-date: block-height,
        total-value: u0,
        risk-score: risk-score,
        status: u1
      }
    )

    ;; Set allocations
    (map-set portfolio-allocations { portfolio-id: portfolio-id, asset-type: ASSET_STOCKS }
      { target-percentage: stock-allocation, current-percentage: u0, current-value: u0 })
    (map-set portfolio-allocations { portfolio-id: portfolio-id, asset-type: ASSET_BONDS }
      { target-percentage: bond-allocation, current-percentage: u0, current-value: u0 })
    (map-set portfolio-allocations { portfolio-id: portfolio-id, asset-type: ASSET_COMMODITIES }
      { target-percentage: commodity-allocation, current-percentage: u0, current-value: u0 })
    (map-set portfolio-allocations { portfolio-id: portfolio-id, asset-type: ASSET_CRYPTO }
      { target-percentage: crypto-allocation, current-percentage: u0, current-value: u0 })
    (map-set portfolio-allocations { portfolio-id: portfolio-id, asset-type: ASSET_CASH }
      { target-percentage: cash-allocation, current-percentage: u0, current-value: u0 })

    (map-set client-portfolios { client: tx-sender } { portfolio-id: portfolio-id })
    (var-set next-portfolio-id (+ portfolio-id u1))
    (ok portfolio-id)
  )
)

;; Update portfolio value
(define-public (update-portfolio-value (portfolio-id uint) (new-total-value uint))
  (match (map-get? portfolios { portfolio-id: portfolio-id })
    portfolio-data (begin
      (asserts! (is-eq tx-sender (get client portfolio-data)) ERR_UNAUTHORIZED)
      (map-set portfolios
        { portfolio-id: portfolio-id }
        (merge portfolio-data { total-value: new-total-value })
      )
      (ok true)
    )
    ERR_PORTFOLIO_NOT_FOUND
  )
)

;; Update asset allocation
(define-public (update-allocation
  (portfolio-id uint)
  (asset-type uint)
  (current-percentage uint)
  (current-value uint)
)
  (match (map-get? portfolios { portfolio-id: portfolio-id })
    portfolio-data (begin
      (asserts! (is-eq tx-sender (get client portfolio-data)) ERR_UNAUTHORIZED)
      (match (map-get? portfolio-allocations { portfolio-id: portfolio-id, asset-type: asset-type })
        allocation-data (begin
          (map-set portfolio-allocations
            { portfolio-id: portfolio-id, asset-type: asset-type }
            (merge allocation-data {
              current-percentage: current-percentage,
              current-value: current-value
            })
          )
          (ok true)
        )
        ERR_PORTFOLIO_NOT_FOUND
      )
    )
    ERR_PORTFOLIO_NOT_FOUND
  )
)

;; Read-only functions
(define-read-only (get-portfolio (portfolio-id uint))
  (map-get? portfolios { portfolio-id: portfolio-id })
)

(define-read-only (get-allocation (portfolio-id uint) (asset-type uint))
  (map-get? portfolio-allocations { portfolio-id: portfolio-id, asset-type: asset-type })
)

(define-read-only (get-client-portfolio (client principal))
  (match (map-get? client-portfolios { client: client })
    portfolio-record (map-get? portfolios { portfolio-id: (get portfolio-id portfolio-record) })
    none
  )
)
