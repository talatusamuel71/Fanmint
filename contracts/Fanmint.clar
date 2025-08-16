(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-unauthorized (err u105))
(define-constant err-perk-not-available (err u106))
(define-constant err-insufficient-tokens (err u107))
(define-constant err-milestone-not-found (err u108))
(define-constant err-milestone-already-claimed (err u109))
(define-constant err-milestone-not-reached (err u110))
(define-constant err-invalid-milestone (err u111))
(define-constant err-subscription-not-found (err u112))
(define-constant err-tier-not-found (err u113))
(define-constant err-already-subscribed (err u114))
(define-constant err-subscription-expired (err u115))
(define-constant err-invalid-tier (err u116))

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
(define-data-var next-milestone-id uint u1)
(define-data-var next-subscription-tier-id uint u1)

(define-map subscription-tiers uint {
    creator: principal,
    name: (string-ascii 50),
    description: (string-ascii 200),
    monthly-cost: uint,
    fan-token-bonus: uint,
    max-subscribers: uint,
    current-subscribers: uint,
    active: bool
})

(define-map subscriber-tiers {subscriber: principal, tier-id: uint} {
    subscribed-at: uint,
    last-payment: uint,
    next-payment-due: uint,
    total-payments: uint,
    active: bool
})

(define-map creator-subscriptions principal {
    total-subscription-revenue: uint,
    active-subscriptions: uint,
    total-tiers: uint
})

(define-map milestones uint {
    creator: principal,
    milestone-type: (string-ascii 20),
    target-value: uint,
    reward-tokens: uint,
    deadline-block: uint,
    claimed: bool,
    achieved: bool,
    achieved-block: uint
})

(define-map creator-milestone-stats principal {
    total-supporters: uint,
    total-stx-received: uint,
    active-perks: uint,
    total-milestones: uint,
    claimed-milestones: uint
})

(define-public (register-creator (name (string-ascii 50)) (description (string-ascii 200)))
    (let ((creator tx-sender))
        (asserts! (is-none (map-get? creators creator)) err-already-exists)
        (map-set creators creator {
            name: name,
            description: description,
            total-tokens-issued: u0,
            active: true
        })
        (map-set creator-milestone-stats creator {
            total-supporters: u0,
            total-stx-received: u0,
            active-perks: u0,
            total-milestones: u0,
            claimed-milestones: u0
        })
        (map-set creator-subscriptions creator {
            total-subscription-revenue: u0,
            active-subscriptions: u0,
            total-tiers: u0
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
        (let ((stats (default-to {total-supporters: u0, total-stx-received: u0, active-perks: u0, total-milestones: u0, claimed-milestones: u0} (map-get? creator-milestone-stats creator))))
            (map-set creator-milestone-stats creator (merge stats {
                total-supporters: (if (is-none (map-get? creator-supporters {creator: creator, supporter: supporter})) 
                    (+ (get total-supporters stats) u1) 
                    (get total-supporters stats)),
                total-stx-received: (+ (get total-stx-received stats) amount)
            }))
        )
        (try! (update-milestone-progress creator))
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
        (let ((stats (default-to {total-supporters: u0, total-stx-received: u0, active-perks: u0, total-milestones: u0, claimed-milestones: u0} (map-get? creator-milestone-stats creator))))
            (map-set creator-milestone-stats creator (merge stats {
                active-perks: (+ (get active-perks stats) u1)
            }))
        )
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

(define-public (create-milestone 
    (milestone-type (string-ascii 20))
    (target-value uint)
    (reward-tokens uint)
    (deadline-blocks uint)
)
    (let (
        (creator tx-sender)
        (milestone-id (var-get next-milestone-id))
        (deadline-block (+ stacks-block-height deadline-blocks))
    )
        (asserts! (is-some (map-get? creators creator)) err-not-found)
        (asserts! (> target-value u0) err-invalid-milestone)
        (asserts! (> reward-tokens u0) err-invalid-milestone)
        (asserts! (> deadline-blocks u0) err-invalid-milestone)
        (asserts! (or (is-eq milestone-type "supporters") 
                      (is-eq milestone-type "stx-received") 
                      (is-eq milestone-type "perks-created")) err-invalid-milestone)
        (map-set milestones milestone-id {
            creator: creator,
            milestone-type: milestone-type,
            target-value: target-value,
            reward-tokens: reward-tokens,
            deadline-block: deadline-block,
            claimed: false,
            achieved: false,
            achieved-block: u0
        })
        (var-set next-milestone-id (+ milestone-id u1))
        (let ((stats (default-to {total-supporters: u0, total-stx-received: u0, active-perks: u0, total-milestones: u0, claimed-milestones: u0} (map-get? creator-milestone-stats creator))))
            (map-set creator-milestone-stats creator (merge stats {
                total-milestones: (+ (get total-milestones stats) u1)
            }))
        )
        (ok milestone-id)
    )
)

(define-public (claim-milestone-reward (milestone-id uint))
    (let (
        (milestone-data (unwrap! (map-get? milestones milestone-id) err-milestone-not-found))
        (creator (get creator milestone-data))
    )
        (asserts! (is-eq tx-sender creator) err-unauthorized)
        (asserts! (get achieved milestone-data) err-milestone-not-reached)
        (asserts! (not (get claimed milestone-data)) err-milestone-already-claimed)
        (asserts! (<= stacks-block-height (get deadline-block milestone-data)) err-milestone-not-reached)
        (try! (ft-mint? fan-token (get reward-tokens milestone-data) creator))
        (map-set milestones milestone-id (merge milestone-data {
            claimed: true
        }))
        (let ((stats (default-to {total-supporters: u0, total-stx-received: u0, active-perks: u0, total-milestones: u0, claimed-milestones: u0} (map-get? creator-milestone-stats creator))))
            (map-set creator-milestone-stats creator (merge stats {
                claimed-milestones: (+ (get claimed-milestones stats) u1)
            }))
        )
        (ok true)
    )
)

(define-private (update-milestone-progress (creator principal))
    (let ((stats (default-to {total-supporters: u0, total-stx-received: u0, active-perks: u0, total-milestones: u0, claimed-milestones: u0} (map-get? creator-milestone-stats creator))))
        (try! (check-and-update-milestone creator "supporters" (get total-supporters stats)))
        (try! (check-and-update-milestone creator "stx-received" (get total-stx-received stats)))
        (try! (check-and-update-milestone creator "perks-created" (get active-perks stats)))
        (ok true)
    )
)

(define-private (check-and-update-milestone (creator principal) (milestone-type (string-ascii 20)) (current-value uint))
    (let ((milestone-search-result (get-creator-milestone-by-type creator milestone-type)))
        (match (get result milestone-search-result)
            some-id (let ((milestone-data (unwrap! (map-get? milestones some-id) err-milestone-not-found)))
                (if (and (not (get achieved milestone-data)) 
                         (>= current-value (get target-value milestone-data))
                         (<= stacks-block-height (get deadline-block milestone-data)))
                    (begin
                        (map-set milestones some-id (merge milestone-data {
                            achieved: true,
                            achieved-block: stacks-block-height
                        }))
                        (ok true)
                    )
                    (ok false)
                )
            )
            (ok false)
        )
    )
)

(define-private (get-creator-milestone-by-type (creator principal) (milestone-type (string-ascii 20)))
    (fold find-milestone-by-type-and-creator (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20) {creator: creator, milestone-type: milestone-type, result: none})
)

(define-private (find-milestone-by-type-and-creator (milestone-id uint) (search-params {creator: principal, milestone-type: (string-ascii 20), result: (optional uint)}))
    (match (get result search-params)
        some-result search-params
        (match (map-get? milestones milestone-id)
            some-milestone (if (and (is-eq (get creator some-milestone) (get creator search-params))
                                   (is-eq (get milestone-type some-milestone) (get milestone-type search-params))
                                   (not (get achieved some-milestone)))
                              (merge search-params {result: (some milestone-id)})
                              search-params)
            search-params
        )
    )
)

(define-read-only (get-milestone-info (milestone-id uint))
    (map-get? milestones milestone-id)
)

(define-read-only (get-creator-milestone-stats (creator principal))
    (map-get? creator-milestone-stats creator)
)

(define-read-only (get-creator-active-milestones (creator principal))
    (let ((milestones-list (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20)))
        (filter is-creator-milestone (map get-milestone-with-id milestones-list))
    )
)

(define-private (get-milestone-with-id (milestone-id uint))
    {milestone-id: milestone-id, milestone-data: (map-get? milestones milestone-id)}
)

(define-private (is-creator-milestone (milestone-info {milestone-id: uint, milestone-data: (optional {creator: principal, milestone-type: (string-ascii 20), target-value: uint, reward-tokens: uint, deadline-block: uint, claimed: bool, achieved: bool, achieved-block: uint})}))
    (match (get milestone-data milestone-info)
        some-data (and (is-eq (get creator some-data) tx-sender) (not (get claimed some-data)))
        false
    )
)

(define-read-only (get-next-milestone-id)
    (var-get next-milestone-id)
)

(define-public (create-subscription-tier
    (name (string-ascii 50))
    (description (string-ascii 200))
    (monthly-cost uint)
    (fan-token-bonus uint)
    (max-subscribers uint)
)
    (let (
        (creator tx-sender)
        (tier-id (var-get next-subscription-tier-id))
    )
        (asserts! (is-some (map-get? creators creator)) err-not-found)
        (asserts! (> monthly-cost u0) err-invalid-tier)
        (asserts! (> max-subscribers u0) err-invalid-tier)
        (map-set subscription-tiers tier-id {
            creator: creator,
            name: name,
            description: description,
            monthly-cost: monthly-cost,
            fan-token-bonus: fan-token-bonus,
            max-subscribers: max-subscribers,
            current-subscribers: u0,
            active: true
        })
        (var-set next-subscription-tier-id (+ tier-id u1))
        (let ((sub-stats (default-to {total-subscription-revenue: u0, active-subscriptions: u0, total-tiers: u0} (map-get? creator-subscriptions creator))))
            (map-set creator-subscriptions creator (merge sub-stats {
                total-tiers: (+ (get total-tiers sub-stats) u1)
            }))
        )
        (ok tier-id)
    )
)

(define-public (subscribe-to-tier (tier-id uint))
    (let (
        (subscriber tx-sender)
        (tier-data (unwrap! (map-get? subscription-tiers tier-id) err-tier-not-found))
        (creator (get creator tier-data))
        (monthly-cost (get monthly-cost tier-data))
        (platform-fee (/ (* monthly-cost (var-get platform-fee-rate)) u10000))
        (creator-amount (- monthly-cost platform-fee))
        (current-block stacks-block-height)
        (next-payment (+ current-block u4320))
    )
        (asserts! (get active tier-data) err-tier-not-found)
        (asserts! (< (get current-subscribers tier-data) (get max-subscribers tier-data)) err-invalid-tier)
        (asserts! (is-none (map-get? subscriber-tiers {subscriber: subscriber, tier-id: tier-id})) err-already-subscribed)
        (try! (stx-transfer? monthly-cost subscriber (as-contract tx-sender)))
        (try! (ft-mint? fan-token creator-amount creator))
        (try! (ft-mint? fan-token (+ creator-amount (get fan-token-bonus tier-data)) subscriber))
        (map-set subscription-tiers tier-id (merge tier-data {
            current-subscribers: (+ (get current-subscribers tier-data) u1)
        }))
        (map-set subscriber-tiers {subscriber: subscriber, tier-id: tier-id} {
            subscribed-at: current-block,
            last-payment: current-block,
            next-payment-due: next-payment,
            total-payments: u1,
            active: true
        })
        (let ((sub-stats (default-to {total-subscription-revenue: u0, active-subscriptions: u0, total-tiers: u0} (map-get? creator-subscriptions creator))))
            (map-set creator-subscriptions creator (merge sub-stats {
                total-subscription-revenue: (+ (get total-subscription-revenue sub-stats) creator-amount),
                active-subscriptions: (+ (get active-subscriptions sub-stats) u1)
            }))
        )
        (ok true)
    )
)

(define-public (process-subscription-payment (tier-id uint) (subscriber principal))
    (let (
        (tier-data (unwrap! (map-get? subscription-tiers tier-id) err-tier-not-found))
        (subscription-data (unwrap! (map-get? subscriber-tiers {subscriber: subscriber, tier-id: tier-id}) err-subscription-not-found))
        (creator (get creator tier-data))
        (monthly-cost (get monthly-cost tier-data))
        (platform-fee (/ (* monthly-cost (var-get platform-fee-rate)) u10000))
        (creator-amount (- monthly-cost platform-fee))
        (current-block stacks-block-height)
        (next-payment (+ current-block u4320))
    )
        (asserts! (get active subscription-data) err-subscription-expired)
        (asserts! (>= current-block (get next-payment-due subscription-data)) err-subscription-not-found)
        (try! (stx-transfer? monthly-cost subscriber (as-contract tx-sender)))
        (try! (ft-mint? fan-token creator-amount creator))
        (try! (ft-mint? fan-token (+ creator-amount (get fan-token-bonus tier-data)) subscriber))
        (map-set subscriber-tiers {subscriber: subscriber, tier-id: tier-id} (merge subscription-data {
            last-payment: current-block,
            next-payment-due: next-payment,
            total-payments: (+ (get total-payments subscription-data) u1)
        }))
        (let ((sub-stats (default-to {total-subscription-revenue: u0, active-subscriptions: u0, total-tiers: u0} (map-get? creator-subscriptions creator))))
            (map-set creator-subscriptions creator (merge sub-stats {
                total-subscription-revenue: (+ (get total-subscription-revenue sub-stats) creator-amount)
            }))
        )
        (ok true)
    )
)

(define-public (cancel-subscription (tier-id uint))
    (let (
        (subscriber tx-sender)
        (tier-data (unwrap! (map-get? subscription-tiers tier-id) err-tier-not-found))
        (subscription-data (unwrap! (map-get? subscriber-tiers {subscriber: subscriber, tier-id: tier-id}) err-subscription-not-found))
        (creator (get creator tier-data))
    )
        (asserts! (get active subscription-data) err-subscription-expired)
        (map-set subscription-tiers tier-id (merge tier-data {
            current-subscribers: (- (get current-subscribers tier-data) u1)
        }))
        (map-set subscriber-tiers {subscriber: subscriber, tier-id: tier-id} (merge subscription-data {
            active: false
        }))
        (let ((sub-stats (default-to {total-subscription-revenue: u0, active-subscriptions: u0, total-tiers: u0} (map-get? creator-subscriptions creator))))
            (map-set creator-subscriptions creator (merge sub-stats {
                active-subscriptions: (- (get active-subscriptions sub-stats) u1)
            }))
        )
        (ok true)
    )
)

(define-public (toggle-subscription-tier-status (tier-id uint))
    (let (
        (creator tx-sender)
        (tier-data (unwrap! (map-get? subscription-tiers tier-id) err-tier-not-found))
    )
        (asserts! (is-eq creator (get creator tier-data)) err-unauthorized)
        (map-set subscription-tiers tier-id (merge tier-data {
            active: (not (get active tier-data))
        }))
        (ok true)
    )
)

(define-public (update-subscription-tier 
    (tier-id uint)
    (new-monthly-cost uint)
    (new-fan-token-bonus uint)
    (new-max-subscribers uint)
)
    (let (
        (creator tx-sender)
        (tier-data (unwrap! (map-get? subscription-tiers tier-id) err-tier-not-found))
    )
        (asserts! (is-eq creator (get creator tier-data)) err-unauthorized)
        (asserts! (> new-monthly-cost u0) err-invalid-tier)
        (asserts! (>= new-max-subscribers (get current-subscribers tier-data)) err-invalid-tier)
        (map-set subscription-tiers tier-id (merge tier-data {
            monthly-cost: new-monthly-cost,
            fan-token-bonus: new-fan-token-bonus,
            max-subscribers: new-max-subscribers
        }))
        (ok true)
    )
)

(define-read-only (get-subscription-tier-info (tier-id uint))
    (map-get? subscription-tiers tier-id)
)

(define-read-only (get-subscriber-info (subscriber principal) (tier-id uint))
    (map-get? subscriber-tiers {subscriber: subscriber, tier-id: tier-id})
)

(define-read-only (get-creator-subscription-stats (creator principal))
    (map-get? creator-subscriptions creator)
)

(define-read-only (get-next-subscription-tier-id)
    (var-get next-subscription-tier-id)
)

(define-read-only (is-subscription-due (subscriber principal) (tier-id uint))
    (match (map-get? subscriber-tiers {subscriber: subscriber, tier-id: tier-id})
        some-subscription (and (get active some-subscription) 
                              (>= stacks-block-height (get next-payment-due some-subscription)))
        false
    )
)

(define-read-only (get-creator-subscription-tiers (creator principal))
    (let ((tiers-list (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20)))
        (filter is-creator-tier (map get-tier-with-id tiers-list))
    )
)

(define-private (get-tier-with-id (tier-id uint))
    {tier-id: tier-id, tier-data: (map-get? subscription-tiers tier-id)}
)

(define-private (is-creator-tier (tier-info {tier-id: uint, tier-data: (optional {creator: principal, name: (string-ascii 50), description: (string-ascii 200), monthly-cost: uint, fan-token-bonus: uint, max-subscribers: uint, current-subscribers: uint, active: bool})}))
    (match (get tier-data tier-info)
        some-data (is-eq (get creator some-data) tx-sender)
        false
    )
)



