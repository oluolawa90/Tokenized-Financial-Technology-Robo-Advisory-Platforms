;; Advisory Firm Verification Contract
;; Manages registration and verification of robo-advisory providers

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_FIRM_EXISTS (err u101))
(define-constant ERR_FIRM_NOT_FOUND (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Firm verification statuses
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_SUSPENDED u2)
(define-constant STATUS_REVOKED u3)

;; Data structures
(define-map advisory-firms
  { firm-id: uint }
  {
    name: (string-ascii 100),
    principal: principal,
    registration-date: uint,
    verification-status: uint,
    aum: uint,  ;; Assets Under Management
    fee-rate: uint  ;; Basis points (e.g., 100 = 1%)
  }
)

(define-map firm-principals
  { principal: principal }
  { firm-id: uint }
)

(define-data-var next-firm-id uint u1)

;; Register a new advisory firm
(define-public (register-firm (name (string-ascii 100)) (fee-rate uint))
  (let ((firm-id (var-get next-firm-id)))
    (asserts! (is-none (map-get? firm-principals { principal: tx-sender })) ERR_FIRM_EXISTS)
    (asserts! (<= fee-rate u1000) ERR_INVALID_STATUS) ;; Max 10% fee

    (map-set advisory-firms
      { firm-id: firm-id }
      {
        name: name,
        principal: tx-sender,
        registration-date: block-height,
        verification-status: STATUS_PENDING,
        aum: u0,
        fee-rate: fee-rate
      }
    )

    (map-set firm-principals
      { principal: tx-sender }
      { firm-id: firm-id }
    )

    (var-set next-firm-id (+ firm-id u1))
    (ok firm-id)
  )
)

;; Verify a firm (admin only)
(define-public (verify-firm (firm-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? advisory-firms { firm-id: firm-id })
      firm-data (begin
        (map-set advisory-firms
          { firm-id: firm-id }
          (merge firm-data { verification-status: STATUS_VERIFIED })
        )
        (ok true)
      )
      ERR_FIRM_NOT_FOUND
    )
  )
)

;; Update firm AUM
(define-public (update-aum (new-aum uint))
  (match (map-get? firm-principals { principal: tx-sender })
    firm-record (match (map-get? advisory-firms { firm-id: (get firm-id firm-record) })
      firm-data (begin
        (map-set advisory-firms
          { firm-id: (get firm-id firm-record) }
          (merge firm-data { aum: new-aum })
        )
        (ok true)
      )
      ERR_FIRM_NOT_FOUND
    )
    ERR_FIRM_NOT_FOUND
  )
)

;; Read-only functions
(define-read-only (get-firm-info (firm-id uint))
  (map-get? advisory-firms { firm-id: firm-id })
)

(define-read-only (get-firm-by-principal (principal principal))
  (match (map-get? firm-principals { principal: principal })
    firm-record (map-get? advisory-firms { firm-id: (get firm-id firm-record) })
    none
  )
)

(define-read-only (is-firm-verified (firm-id uint))
  (match (map-get? advisory-firms { firm-id: firm-id })
    firm-data (is-eq (get verification-status firm-data) STATUS_VERIFIED)
    false
  )
)
