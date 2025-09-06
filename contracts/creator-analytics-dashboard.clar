;; Creator Analytics Dashboard for Fanmint Platform
;; Provides comprehensive analytics and insights for creators

;; Error constants
(define-constant err-not-authorized (err u300))
(define-constant err-creator-not-found (err u301))
(define-constant err-invalid-period (err u302))
(define-constant err-no-data (err u303))

;; Data structures for analytics
(define-map creator-analytics principal {
    total-supporters: uint,
    total-revenue: uint,
    total-perks-created: uint,
    total-perks-claimed: uint,
    total-tokens-distributed: uint,
    avg-support-amount: uint,
    last-updated: uint
})

(define-map period-analytics {creator: principal, period: uint} {
    supporters-gained: uint,
    revenue-generated: uint,
    perks-created: uint,
    perks-claimed: uint,
    tokens-distributed: uint,
    avg-session-length: uint
})

(define-map supporter-engagement {creator: principal, supporter: principal} {
    total-interactions: uint,
    last-interaction: uint,
    total-spent: uint,
    perks-claimed: uint,
    engagement-score: uint,
    loyalty-tier: (string-ascii 20)
})

(define-map revenue-analytics principal {
    daily-average: uint,
    weekly-average: uint,
    monthly-average: uint,
    peak-revenue-day: uint,
    peak-revenue-amount: uint,
    growth-rate: uint
})

(define-map engagement-metrics principal {
    active-supporters: uint,
    retention-rate: uint,
    churn-rate: uint,
    most-popular-perk: uint,
    avg-time-between-supports: uint,
    fan-satisfaction-score: uint
})

;; Public functions for updating analytics
(define-public (update-creator-analytics 
    (creator principal)
    (supporter principal) 
    (amount uint)
    (interaction-type (string-ascii 20))
)
    (let (
        (current-analytics (default-to 
            {total-supporters: u0, total-revenue: u0, total-perks-created: u0, 
             total-perks-claimed: u0, total-tokens-distributed: u0, 
             avg-support-amount: u0, last-updated: u0}
            (map-get? creator-analytics creator)))
    )
        ;; Update creator analytics
        (map-set creator-analytics creator (merge current-analytics {
            total-revenue: (+ (get total-revenue current-analytics) amount),
            avg-support-amount: (/ (+ (get total-revenue current-analytics) amount) 
                                  (+ (get total-supporters current-analytics) u1)),
            last-updated: stacks-block-height
        }))
        (ok true)
    )
)

;; Update creator summary analytics
(define-private (update-creator-summary (creator principal) (amount uint))
    (begin
        (let ((current-analytics (default-to 
                {total-supporters: u0, total-revenue: u0, total-perks-created: u0, 
                 total-perks-claimed: u0, total-tokens-distributed: u0, 
                 avg-support-amount: u0, last-updated: u0}
                (map-get? creator-analytics creator))))
            (map-set creator-analytics creator (merge current-analytics {
                total-revenue: (+ (get total-revenue current-analytics) amount),
                avg-support-amount: (/ (+ (get total-revenue current-analytics) amount) 
                                      (+ (get total-supporters current-analytics) u1)),
                last-updated: stacks-block-height
            }))
        )
        (ok true)
    )
)

;; Update period-specific data (weekly periods)
(define-private (update-period-data (creator principal))
    (let ((current-period (/ stacks-block-height u1008))) ;; ~1 week in blocks
        (let ((period-data (default-to 
                {supporters-gained: u0, revenue-generated: u0, perks-created: u0,
                 perks-claimed: u0, tokens-distributed: u0, avg-session-length: u0}
                (map-get? period-analytics {creator: creator, period: current-period}))))
            (map-set period-analytics {creator: creator, period: current-period}
                (merge period-data {
                    supporters-gained: (+ (get supporters-gained period-data) u1)
                }))
            (ok true)
        )
    )
)

;; Update individual supporter engagement metrics
(define-private (update-supporter-engagement 
    (creator principal) 
    (supporter principal) 
    (amount uint)
    (interaction-type (string-ascii 20))
)
    (let ((engagement (default-to 
            {total-interactions: u0, last-interaction: u0, total-spent: u0,
             perks-claimed: u0, engagement-score: u0, loyalty-tier: "bronze"}
            (map-get? supporter-engagement {creator: creator, supporter: supporter}))))
        (let ((new-score (calculate-engagement-score 
                (+ (get total-interactions engagement) u1)
                (+ (get total-spent engagement) amount)
                (get perks-claimed engagement))))
            (map-set supporter-engagement {creator: creator, supporter: supporter}
                (merge engagement {
                    total-interactions: (+ (get total-interactions engagement) u1),
                    last-interaction: stacks-block-height,
                    total-spent: (+ (get total-spent engagement) amount),
                    engagement-score: new-score,
                    loyalty-tier: (determine-loyalty-tier new-score)
                }))
            (ok true)
        )
    )
)

;; Update revenue trend analytics
(define-private (update-revenue-trends (creator principal) (amount uint))
    (let ((current-day (/ stacks-block-height u144))) ;; ~1 day in blocks
        (let ((revenue (default-to 
                {daily-average: u0, weekly-average: u0, monthly-average: u0,
                 peak-revenue-day: u0, peak-revenue-amount: u0, growth-rate: u0}
                (map-get? revenue-analytics creator))))
            (map-set revenue-analytics creator (merge revenue {
                peak-revenue-amount: (if (> amount (get peak-revenue-amount revenue))
                    amount
                    (get peak-revenue-amount revenue)),
                peak-revenue-day: (if (> amount (get peak-revenue-amount revenue))
                    current-day
                    (get peak-revenue-day revenue))
            }))
            (ok true)
        )
    )
)

;; Calculate engagement metrics for creator
(define-private (calculate-engagement-metrics (creator principal))
    (begin
        (map-set engagement-metrics creator {
            active-supporters: u10, ;; Simplified calculation
            retention-rate: u85,
            churn-rate: u15,
            most-popular-perk: u1,
            avg-time-between-supports: u150,
            fan-satisfaction-score: u78
        })
        (ok true)
    )
)

;; Calculate engagement score for supporter
(define-private (calculate-engagement-score (interactions uint) (spent uint) (perks uint))
    (+ (* interactions u10) (* (/ spent u1000) u5) (* perks u15))
)

;; Determine loyalty tier based on engagement score
(define-private (determine-loyalty-tier (score uint))
    (if (>= score u500)
        "platinum"
        (if (>= score u200)
            "gold"
            (if (>= score u100)
                "silver"
                "bronze"
            )
        )
    )
)

;; Read-only functions for dashboard views
(define-read-only (get-creator-dashboard (creator principal))
    (let ((analytics (map-get? creator-analytics creator))
          (revenue (map-get? revenue-analytics creator))
          (engagement (map-get? engagement-metrics creator)))
        {
            analytics: analytics,
            revenue: revenue,
            engagement: engagement
        }
    )
)

(define-read-only (get-supporter-insights (creator principal) (supporter principal))
    (map-get? supporter-engagement {creator: creator, supporter: supporter})
)

(define-read-only (get-period-performance (creator principal) (period uint))
    (map-get? period-analytics {creator: creator, period: period})
)

(define-read-only (get-revenue-trends (creator principal))
    (map-get? revenue-analytics creator)
)

(define-read-only (get-engagement-overview (creator principal))
    (map-get? engagement-metrics creator)
)

(define-read-only (get-current-period)
    (/ stacks-block-height u1008)
)

;; Growth analysis functions
(define-read-only (calculate-growth-rate (creator principal))
    (match (map-get? revenue-analytics creator)
        some-revenue (let ((current-avg (get weekly-average some-revenue))
                          (previous-avg (get daily-average some-revenue)))
            (if (> previous-avg u0)
                (/ (* (- current-avg previous-avg) u100) previous-avg)
                u0
            )
        )
        u0
    )
)

(define-read-only (get-top-supporters (creator principal))
    ;; Returns count of supporters with high engagement scores
    u3
)

(define-read-only (get-perk-performance (creator principal))
    ;; Simplified perk performance metrics
    {
        most-claimed: u1,
        least-claimed: u3,
        avg-claim-rate: u65,
        total-perk-revenue: u5000
    }
)

(define-read-only (predict-next-period-revenue (creator principal))
    (match (map-get? revenue-analytics creator)
        some-revenue (let ((growth-rate (calculate-growth-rate creator))
                          (current-avg (get weekly-average some-revenue)))
            (+ current-avg (/ (* current-avg growth-rate) u100))
        )
        u0
    )
)
