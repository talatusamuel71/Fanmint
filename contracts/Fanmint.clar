(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-unauthorized (err u105))
(define-constant err-perk-not-available (err u106))
(define-constant err-insufficient-tokens (err u107))

(define-fungible-token fan-token)

(define-map creators principal {
    name: (string-ascii 50),
    description: (string-ascii 200),
    total-tokens-issued: uint,
    active: bool
})

(define-map perks uint {
    creator: principal,
    name: (string-ascii 50),
    description: (string-ascii 200),
    cost: uint,
    max-supply: uint,
    current-supply: uint,
    active: bool
})

(define-map user-perks {user: principal, perk-id: uint} {
    claimed-at: uint,
    active: bool
})

(define-map creator-supporters {creator: principal, supporter: principal} {
    total-tokens-earned: uint,
    first-support-block: uint,
    last-support-block: uint
})

(define-data-var next-perk-id uint u1)
(define-data-var platform-fee-rate uint u250)

(define-public (register-creator (name (string-ascii 50)) (description (string-ascii 200)))
    (let ((creator tx-sender))
        (asserts! (is-none (map-get? creators creator)) err-already-exists)
        (map-set creators creator {
            name: name,
            description: description,
            total-tokens-issued: u0,
            active: true
        })
        (ok true)
    )
)

(define-public (support-creator (creator principal) (amount uint))
    (let (
        (supporter tx-sender)
        (creator-data (unwrap! (map-get? creators creator) err-not-found))
        (platform-fee (/ (* amount (var-get platform-fee-rate)) u10000))
        (creator-amount (- amount platform-fee))
    )
        (asserts! (> amount u0) err-invalid-amount)
        (asserts! (get active creator-data) err-not-found)
        (try! (stx-transfer? amount supporter (as-contract tx-sender)))
        (try! (ft-mint? fan-token creator-amount creator))
        (try! (ft-mint? fan-token creator-amount supporter))
        (map-set creators creator (merge creator-data {
            total-tokens-issued: (+ (get total-tokens-issued creator-data) (* creator-amount u2))
        }))
        (map-set creator-supporters {creator: creator, supporter: supporter} 
            (match (map-get? creator-supporters {creator: creator, supporter: supporter})
                existing-support (merge existing-support {
                    total-tokens-earned: (+ (get total-tokens-earned existing-support) creator-amount),
                    last-support-block: stacks-block-height
                })
                {
                    total-tokens-earned: creator-amount,
                    first-support-block: stacks-block-height,
                    last-support-block: stacks-block-height
                }
            )
        )
        (ok true)
    )
)

(define-public (create-perk 
    (name (string-ascii 50)) 
    (description (string-ascii 200)) 
    (cost uint) 
    (max-supply uint)
)
    (let (
        (creator tx-sender)
        (perk-id (var-get next-perk-id))
    )
        (asserts! (is-some (map-get? creators creator)) err-not-found)
        (asserts! (> cost u0) err-invalid-amount)
        (asserts! (> max-supply u0) err-invalid-amount)
        (map-set perks perk-id {
            creator: creator,
            name: name,
            description: description,
            cost: cost,
            max-supply: max-supply,
            current-supply: u0,
            active: true
        })
        (var-set next-perk-id (+ perk-id u1))
        (ok perk-id)
    )
)

(define-public (claim-perk (perk-id uint))
    (let (
        (user tx-sender)
        (perk-data (unwrap! (map-get? perks perk-id) err-not-found))
        (user-balance (ft-get-balance fan-token user))
    )
        (asserts! (get active perk-data) err-perk-not-available)
        (asserts! (< (get current-supply perk-data) (get max-supply perk-data)) err-perk-not-available)
        (asserts! (>= user-balance (get cost perk-data)) err-insufficient-tokens)
        (asserts! (is-none (map-get? user-perks {user: user, perk-id: perk-id})) err-already-exists)
        (try! (ft-burn? fan-token (get cost perk-data) user))
        (map-set perks perk-id (merge perk-data {
            current-supply: (+ (get current-supply perk-data) u1)
        }))
        (map-set user-perks {user: user, perk-id: perk-id} {
            claimed-at: stacks-block-height,
            active: true
        })
        (ok true)
    )
)

(define-public (toggle-creator-status)
    (let (
        (creator tx-sender)
        (creator-data (unwrap! (map-get? creators creator) err-not-found))
    )
        (map-set creators creator (merge creator-data {
            active: (not (get active creator-data))
        }))
        (ok true)
    )
)

(define-public (toggle-perk-status (perk-id uint))
    (let (
        (creator tx-sender)
        (perk-data (unwrap! (map-get? perks perk-id) err-not-found))
    )
        (asserts! (is-eq creator (get creator perk-data)) err-unauthorized)
        (map-set perks perk-id (merge perk-data {
            active: (not (get active perk-data))
        }))
        (ok true)
    )
)

(define-public (withdraw-funds (amount uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (as-contract (stx-transfer? amount tx-sender contract-owner))
    )
)

(define-public (update-platform-fee (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= new-rate u1000) err-invalid-amount)
        (var-set platform-fee-rate new-rate)
        (ok true)
    )
)

(define-read-only (get-creator-info (creator principal))
    (map-get? creators creator)
)

(define-read-only (get-perk-info (perk-id uint))
    (map-get? perks perk-id)
)

(define-read-only (get-user-perk (user principal) (perk-id uint))
    (map-get? user-perks {user: user, perk-id: perk-id})
)

(define-read-only (get-support-info (creator principal) (supporter principal))
    (map-get? creator-supporters {creator: creator, supporter: supporter})
)

(define-read-only (get-fan-token-balance (user principal))
    (ft-get-balance fan-token user)
)

(define-read-only (get-fan-token-supply)
    (ft-get-supply fan-token)
)

(define-read-only (get-platform-fee-rate)
    (var-get platform-fee-rate)
)

(define-read-only (get-next-perk-id)
    (var-get next-perk-id)
)

(define-read-only (has-claimed-perk (user principal) (perk-id uint))
    (is-some (map-get? user-perks {user: user, perk-id: perk-id}))
)