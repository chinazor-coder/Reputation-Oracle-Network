;; Reputation Oracle Network
;; A decentralized reputation system where validators stake tokens to provide reputation scores
;; Users can query reputation and validators earn fees for accurate assessments

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-validator (err u101))
(define-constant err-insufficient-stake (err u102))
(define-constant err-entity-not-found (err u103))
(define-constant err-already-voted (err u104))
(define-constant err-invalid-score (err u105))
(define-constant err-insufficient-balance (err u106))
(define-constant err-cooldown-active (err u107))
(define-constant err-validator-exists (err u108))

(define-constant min-validator-stake u1000000) ;; 1 STX in microSTX
(define-constant query-fee u10000) ;; 0.01 STX
(define-constant cooldown-period u144) ;; ~1 day in blocks

;; Data Variables
(define-data-var total-validators uint u0)
(define-data-var protocol-treasury uint u0)

;; Data Maps
(define-map validators
    principal
    {
        stake: uint,
        reputation-score: uint,
        total-assessments: uint,
        accurate-assessments: uint,
        registered-at: uint,
        is-active: bool
    }
)

(define-map entities
    {entity-id: (string-ascii 64)}
    {
        total-score: uint,
        assessment-count: uint,
        created-at: uint,
        last-updated: uint
    }
)

(define-map validator-assessments
    {validator: principal, entity-id: (string-ascii 64)}
    {
        score: uint,
        timestamp: uint,
        weight: uint
    }
)

(define-map query-history
    {querier: principal, entity-id: (string-ascii 64)}
    uint ;; last query block
)

;; Private Functions
(define-private (calculate-validator-weight (validator-data {stake: uint, reputation-score: uint, total-assessments: uint, accurate-assessments: uint, registered-at: uint, is-active: bool}))
    (let
        (
            (base-weight (/ (get stake validator-data) min-validator-stake))
            (reputation-multiplier (if (> (get total-assessments validator-data) u0)
                (/ (* (get accurate-assessments validator-data) u100) (get total-assessments validator-data))
                u50))
        )
        (/ (* base-weight reputation-multiplier) u100)
    )
)

;; Public Functions

;; Register as a validator by staking tokens
(define-public (register-validator (stake-amount uint))
    (let
        (
            (caller tx-sender)
            (current-block stacks-block-height)
        )
        (asserts! (>= stake-amount min-validator-stake) err-insufficient-stake)
        (asserts! (is-none (map-get? validators caller)) err-validator-exists)
        
        (try! (stx-transfer? stake-amount caller (as-contract tx-sender)))
        
        (map-set validators caller {
            stake: stake-amount,
            reputation-score: u50,
            total-assessments: u0,
            accurate-assessments: u0,
            registered-at: current-block,
            is-active: true
        })
        
        (var-set total-validators (+ (var-get total-validators) u1))
        (ok true)
    )
)

;; Submit reputation assessment for an entity
(define-public (submit-assessment (entity-id (string-ascii 64)) (score uint))
    (let
        (
            (caller tx-sender)
            (current-block stacks-block-height)
            (validator-data (unwrap! (map-get? validators caller) err-not-validator))
        )
        (asserts! (get is-active validator-data) err-not-validator)
        (asserts! (and (>= score u0) (<= score u100)) err-invalid-score)
        (asserts! (is-none (map-get? validator-assessments {validator: caller, entity-id: entity-id})) err-already-voted)
        
        (let
            (
                (weight (calculate-validator-weight validator-data))
                (weighted-score (* score weight))
                (entity-data (default-to 
                    {total-score: u0, assessment-count: u0, created-at: current-block, last-updated: current-block}
                    (map-get? entities {entity-id: entity-id})
                ))
            )
            ;; Record validator assessment
            (map-set validator-assessments 
                {validator: caller, entity-id: entity-id}
                {score: score, timestamp: current-block, weight: weight}
            )
            
            ;; Update entity data
            (map-set entities {entity-id: entity-id} {
                total-score: (+ (get total-score entity-data) weighted-score),
                assessment-count: (+ (get assessment-count entity-data) weight),
                created-at: (get created-at entity-data),
                last-updated: current-block
            })
            
            ;; Update validator stats
            (map-set validators caller (merge validator-data {
                total-assessments: (+ (get total-assessments validator-data) u1)
            }))
            
            (ok true)
        )
    )
)

;; Query reputation of an entity (pays fee)
(define-public (query-reputation (entity-id (string-ascii 64)))
    (let
        (
            (caller tx-sender)
            (current-block stacks-block-height)
            (entity-data (unwrap! (map-get? entities {entity-id: entity-id}) err-entity-not-found))
            (last-query (default-to u0 (map-get? query-history {querier: caller, entity-id: entity-id})))
        )
        (asserts! (> current-block (+ last-query cooldown-period)) err-cooldown-active)
        
        (try! (stx-transfer? query-fee caller (as-contract tx-sender)))
        
        (var-set protocol-treasury (+ (var-get protocol-treasury) query-fee))
        
        (map-set query-history {querier: caller, entity-id: entity-id} current-block)
        
        (let
            (
                (reputation (if (> (get assessment-count entity-data) u0)
                    (/ (get total-score entity-data) (get assessment-count entity-data))
                    u0))
            )
            (ok {
                reputation: reputation,
                assessments: (get assessment-count entity-data),
                last-updated: (get last-updated entity-data)
            })
        )
    )
)

;; Increase validator stake
(define-public (increase-stake (amount uint))
    (let
        (
            (caller tx-sender)
            (validator-data (unwrap! (map-get? validators caller) err-not-validator))
        )
        (try! (stx-transfer? amount caller (as-contract tx-sender)))
        
        (map-set validators caller (merge validator-data {
            stake: (+ (get stake validator-data) amount)
        }))
        
        (ok true)
    )
)

;; Withdraw validator stake (deactivates validator)
(define-public (withdraw-stake)
    (let
        (
            (caller tx-sender)
            (validator-data (unwrap! (map-get? validators caller) err-not-validator))
            (stake-amount (get stake validator-data))
        )
        (asserts! (get is-active validator-data) err-not-validator)
        
        (try! (as-contract (stx-transfer? stake-amount tx-sender caller)))
        
        (map-set validators caller (merge validator-data {
            stake: u0,
            is-active: false
        }))
        
        (var-set total-validators (- (var-get total-validators) u1))
        (ok stake-amount)
    )
)

;; Read-only functions
(define-read-only (get-entity-reputation (entity-id (string-ascii 64)))
    (let
        (
            (entity-data (map-get? entities {entity-id: entity-id}))
        )
        (match entity-data
            data (ok {
                reputation: (if (> (get assessment-count data) u0)
                    (/ (get total-score data) (get assessment-count data))
                    u0),
                assessments: (get assessment-count data),
                created-at: (get created-at data),
                last-updated: (get last-updated data)
            })
            err-entity-not-found
        )
    )
)

(define-read-only (get-validator-info (validator principal))
    (map-get? validators validator)
)

(define-read-only (get-validator-assessment (validator principal) (entity-id (string-ascii 64)))
    (map-get? validator-assessments {validator: validator, entity-id: entity-id})
)

(define-read-only (get-total-validators)
    (ok (var-get total-validators))
)

(define-read-only (get-protocol-treasury)
    (ok (var-get protocol-treasury))
)